defmodule Fedi.ActivityPub.SideEffectActor do
  @moduledoc """
  SideEffectActor handles the ActivityPub
  implementation side effects, but requires a more opinionated application to
  be written.

  Note that when using the SideEffectActor with an application that good-faith
  implements its required interfaces, the ActivityPub specification is
  guaranteed to be correctly followed.

  These optional callbacks are directly delegated by the
  Fedi.ActivityPub.Actor module to implementation modules:

    * `authenticate_get_outbox/2` - :common
    * `get_outbox/2` - :common
    * `authenticate_get_inbox/2` - :common
    * `get_inbox/2` - :common
    * `authenticate_post_outbox/2` - :c2s
    * `post_outbox_request_body_hook/3` - :c2s
    * `authenticate_post_inbox/2` - :s2s
    * `post_inbox_request_body_hook/3` - :s2s

  See the `FediServerWeb.SocialCallbacks` module in the fedi_server
  example application for an implementation.
  """

  @behaviour Fedi.ActivityPub.ActorBehavior

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityPub.Actor
  alias Fedi.ActivityPub.Utils, as: APUtils

  @enforce_keys [:common]
  defstruct [
    :common,
    :c2s,
    :s2s,
    :c2s_activity_handler,
    :s2s_activity_handler,
    :fallback,
    :database,
    :social_api_enabled?,
    :federated_protocol_enabled?,
    :data
  ]

  @type t() :: %__MODULE__{
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          c2s_activity_handler: module() | nil,
          s2s_activity_handler: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          social_api_enabled?: boolean(),
          federated_protocol_enabled?: boolean(),
          data: term()
        }

  # Same as above but just a map
  @type context() :: %{
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          c2s_activity_handler: module() | nil,
          s2s_activity_handler: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          social_api_enabled?: boolean(),
          federated_protocol_enabled?: boolean(),
          data: term()
        }

  def new(common, opts \\ []) do
    opts =
      Keyword.merge(
        [
          c2s_activity_handler: Fedi.ActivityPub.SocialActivityHandler,
          s2s_activity_handler: Fedi.ActivityPub.FederatingActivityHandler
        ],
        opts
      )

    Fedi.ActivityPub.Actor.make_actor(__MODULE__, common, opts)
  end

  ### common delegations

  ### c2s delegations

  @doc """
  Delegates the authentication and authorization
  of a POST to an outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  post_outbox. In this case, the implementation must not write a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles writing to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  def authenticate_post_outbox(context, %Plug.Conn{} = conn) do
    Actor.delegate(context, :c2s, :authenticate_post_outbox, [conn])
  end

  @doc """
  """
  def post_outbox_body_hook(context, %Plug.Conn{} = conn) do
    Actor.delegate(context, :c2s, :post_outbox_body_hook, [conn])
  end

  ### s2s delegations

  ### SideEffectActor implementation

  @doc """
  Defers to the federating protocol whether the peer request
  is authorized based on the actors' ids.
  """
  def authorize_post_inbox(%{s2s: nil} = _context, _, _) do
    :pass
  end

  def authorize_post_inbox(%{s2s: _} = context, %Plug.Conn{} = conn, activity)
      when is_struct(activity) do
    with {:activity_actor, %P.Actor{values: [_ | _]} = actor_prop} <-
           {:activity_actor, Utils.get_actor(activity)},
         {:ok, actor_ids} <- APUtils.get_ids(actor_prop) do
      # Determine if the actor(s) sending this request are blocked.
      case Actor.delegate(context, :s2s, :blocked, [actor_ids]) do
        {:ok, unauthorized} ->
          {:ok, conn, !unauthorized}

        {:error, :callback_not_found} ->
          {:ok, conn, true}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
    end
  end

  @doc """
  Handles the side effects of determining whether to block the peer's
  request, adding the activity to the actor's inbox, and triggering side
  effects based on the activity's type.
  """
  def post_inbox(context, %Plug.Conn{} = conn, %URI{} = inbox_iri, activity)
      when is_struct(context) and is_struct(activity) do
    case add_to_inbox_if_new(context, inbox_iri, activity) do
      {:error, reason} ->
        {:error, reason}

      {:ok, false} ->
        # Already in our inbox, all good
        {:ok, conn}

      {:ok, true} ->
        # A new activity was added to the inbox
        if Actor.protocol_supported?(context, :s2s) do
          context = wrap_for_federated_protocol(context, inbox_iri)

          case Actor.handle_activity(context, :s2s, activity, top_level: true) do
            {:error, reason} -> {:error, reason}
            _ -> {:ok, conn}
          end
        end
    end
  end

  @doc """
  Implements the 3-part inbox forwarding algorithm specified in
  the ActivityPub specification. Does not modify the Activity, but may send
  outbound requests as a side effect.

  Sets the federated data in the database.

  Ref: [AP Section 7.1.2](https://w3.org/TR/activitypub/#inbox-forwarding)
  """
  def inbox_forwarding(%{database: database} = context, %URI{} = inbox_iri, activity) do
    # Ref: This is the first time the server has seen this Activity.
    case Utils.get_json_ld_id(activity) do
      %URI{} = id ->
        # See if we have seen the activity
        with {:exists, {:ok, false}} <-
               {:exists, apply(database, :exists, [id])},
             # Attempt to create the activity entry.
             {:ok, _created, _raw_json} <-
               apply(database, :create, [activity]),
             # Ref: The values of 'to', 'cc', or 'audience' are Collections owned by this server.
             {:ok, my_iris} <-
               owned_recipients(database, activity),
             # Finally, load our IRIs to determine if they are a Collection or
             # OrderedCollection.
             {:ok, col_iris, cols, ocols} <-
               get_collection_types(database, my_iris) do
          # If we own none of the Collection IRIs in 'to', 'cc', or 'audience'
          # then no need to do inbox forwarding. We have nothing to forward to.
          if Enum.empty?(col_iris) do
            Logger.debug("No inbox fowarding needed: no collections in recipients")
            :ok
          else
            # Ref: The values of 'inReplyTo', 'object', 'target' and/or 'tag' are objects owned by the server.
            # The server SHOULD recurse through these values to look for linked objects
            # owned by the server, and SHOULD set a maximum limit for recursion.

            # This is only a boolean trigger: As soon as we get
            # a hit that we own something, then we should do inbox forwarding.
            with {:ok, max_depth} <-
                   Actor.delegate(context, :s2s, :max_inbox_forwarding_recursion_depth, []),
                 {:ok, owns_value} <-
                   has_inbox_forwarding_values(context, inbox_iri, activity, max_depth, 0) do
              # If we don't own any of the 'inReplyTo', 'object', 'target', or 'tag'
              # values, then no need to do inbox forwarding.
              if !owns_value do
                :ok
              else
                # Do the inbox forwarding since the above conditions hold true. Support
                # the behavior of letting the application filter out the resulting
                # collections to be targeted.
                with {:ok, recipients} <-
                       get_collection_recipients(context, col_iris, cols, ocols, activity) do
                  deliver_to_recipients(context, activity, recipients)
                end

                # else {:error, reason}
              end
            end
          end
        else
          {:error, reason} ->
            Logger.error("Inbox forwarding error for #{URI.to_string(id)}: #{reason}")
            {:error, reason}

          # We have seen the activity before
          {:exists, {:ok, _}} ->
            Logger.debug("No inbox forwarding needed: #{URI.to_string(id)} has been seen")
            :ok
        end

      nil ->
        {:error, "No id in activity"}
    end
  end

  @doc """
  Finds all IRIs of 'to', 'cc', or 'audience' that are owned by this server.
  We need to find all of them so that forwarding can properly occur.

  Ref: [AP Section 7.1.1](https://www.w3.org/TR/activitypub/#outbox-delivery)
  When objects are received in the outbox (for servers which support both
  Client to Server interactions and Server to Server Interactions), the
  server MUST target and deliver to:

  The to, bto, cc, bcc or audience fields if their values are individuals
  or Collections owned by the actor.
  """
  def owned_recipients(database, activity) do
    with {:ok, recipients} <- APUtils.get_recipients(activity, which: :direct_only) do
      Enum.reduce_while(recipients, [], fn iri, acc ->
        case apply(database, :owns, [iri]) do
          {:error, reason} -> {:halt, {:error, reason}}
          {:ok, true} -> {:cont, [iri | acc]}
          _ -> acc
        end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        recipients -> {:ok, Enum.reverse(recipients)}
      end
    end
  end

  @doc """
  Loads the recipient iris and separates them into OrderedCollection and
  Collection values.
  """
  def get_collection_types(database, iris) do
    # Load the unfiltered IRIs.
    Enum.reduce_while(iris, {[], %{}, %{}}, fn iri, {iri_acc, col_acc, ocol_acc} = acc ->
      case apply(database, :get, [iri]) do
        {:error, reason} ->
          {:halt, {:error, reason}}

        {:ok, as_value} ->
          cond do
            APUtils.is_or_extends?(as_value, "OrderedCollection") ->
              {:cont, {[iri | iri_acc], col_acc, Map.put(ocol_acc, iri, as_value)}}

            APUtils.is_or_extends?(as_value, "Collection") ->
              {:cont, {[iri | iri_acc], Map.put(col_acc, iri, as_value), ocol_acc}}

            true ->
              Logger.error(
                "Owned recipient is a #{Utils.alias_module(as_value.__struct__)}, neither an OrderedCollection nor a Collection"
              )

              {:cont, acc}
          end
      end
    end)
    |> case do
      {:error, reason} ->
        {:error, reason}

      {col_iris, cols, ocols} ->
        {:ok, col_iris, cols, ocols}
    end
  end

  @doc """
  Filter the list of collection ids, then gather the ids contained
  within the collections.

  Ref: [AP Section 7.1.1](https://www.w3.org/TR/activitypub/#outbox-delivery)
  When objects are received in the outbox (for servers which support both
  Client to Server interactions and Server to Server Interactions), the
  server MUST target and deliver to:

  The to, bto, cc, bcc or audience fields if their values are individuals
  or Collections owned by the actor.
  """
  def get_collection_recipients(context, col_iris, cols, ocols, activity) do
    case Actor.delegate(context, :s2s, :filter_forwarding, [col_iris, activity]) do
      {:error, reason} ->
        {:error, reason}

      {:ok, to_send} ->
        Enum.reduce_while(to_send, [], fn iri, acc ->
          cond do
            %{properties: %{"items" => prop}} = Map.get(cols, iri) ->
              case APUtils.to_id(prop) do
                %URI{} = id -> {:cont, [id | acc]}
                _ -> {:halt, {:error, "No id in type"}}
              end

            %{properties: %{"orderedItems" => prop}} = Map.get(ocols, iri) ->
              case APUtils.to_id(prop) do
                %URI{} = id -> {:cont, [id | acc]}
                _ -> {:halt, {:error, "No id in type"}}
              end

            true ->
              {:cont, acc}
          end
        end)
        |> case do
          {:error, reason} -> {:error, reason}
          ids -> {:ok, ids |> MapSet.new() |> MapSet.to_list()}
        end
    end
  end

  @doc """
  Handles the side effects of adding the activity to the actor's
  outbox, and triggering side effects based on the activity's type.

  This implementation assumes all types are meant to be delivered except for
  the ActivityStreams Block type.
  """
  def post_outbox(context, activity, %URI{} = outbox_iri, raw_json) do
    {context, activity} =
      if Actor.protocol_supported?(context, :c2s) do
        context = wrap_for_social_api(context, outbox_iri, raw_json)

        case Actor.handle_activity(context, :c2s, activity, top_level: true) do
          {:ok, new_actor, new_activity} -> {new_actor, new_activity}
          _ -> {context, activity}
        end
      else
        {context, activity}
      end

    with {:ok, _activity, context_data} <- add_to_outbox(context, outbox_iri, activity) do
      case context_data do
        %{undeliverable: undeliverable} ->
          {:ok, !undeliverable}

        _ ->
          Logger.error("No context data returned from add_to_outbox - won't deliver!")
          {:ok, false}
      end
    end
  end

  @doc """
  Creates new 'id' entries on an activity and its objects if it is a
  Create activity.


  """
  def add_new_ids(context, activity) do
    with {:ok, activity} <- set_object_id(context, activity),
         true <- APUtils.is_or_extends?(activity, "Create") do
      APUtils.update_objects(activity, fn object ->
        set_object_id(context, object)
      end)
    else
      false -> {:error, "Not a Create activity"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Completes the peer-to-peer sending of a federated message to
  another server.

  Called if the Federated protocol is supported.
  """
  def deliver(context, outbox_iri, activity) do
    with {:ok, context, activity, recipients} <- prepare(context, outbox_iri, activity) do
      wrap_for_federated_protocol(context, outbox_iri)
      |> deliver_to_recipients(activity, recipients)
    end
  end

  @doc """
  Wraps an object with a Create activity.
  """
  def wrap_in_create(%{database: database} = _context, activity, %URI{} = outbox_iri) do
    with {:ok, actor_iri} <- apply(database, :actor_for_outbox, [outbox_iri]) do
      {:ok, APUtils.wrap_in_create(activity, actor_iri)}
    end
  end

  ### Implementation details

  @doc """
  Adds the activity to the outbox and creates the activity in the
  internal database as its own entry.

  Ref: [AP Section 6](https://www.w3.org/TR/activitypub/#client-to-server-interactions)
  The server MUST then add this new Activity to the outbox collection.
  """
  def add_to_outbox(%{database: database} = context, %URI{} = outbox_iri, activity) do
    with {:activity_id, %URI{} = _id} <- {:activity_id, Utils.get_json_ld_id(activity)},
         # Persist the activity
         {:ok, activity, _raw_json} <-
           apply(database, :create, [activity]),
         # Persist a reference to the activity in the outbox
         # Then return the the list of 'orderedItems'.
         {:ok, _ordered_collection_page} <-
           apply(database, :update_outbox, [outbox_iri, %{create: [activity]}]) do
      {:ok, activity, context.data}
    else
      {:error, reason} ->
        {:error, reason}

      {:activity_id, _} ->
        {:error, Utils.err_id_required(activity: activity)}
    end
  end

  @doc """
  Takes a deliverable object and returns a list of the proper recipient
  target URIs. Additionally, the deliverable object will have any hidden
  hidden recipients ("bto" and "bcc") stripped from it.

  Only called if both the Social API and Federated Protocol are supported.
  """
  def prepare(%{database: database} = context, %URI{} = outbox_iri, %{properties: _} = activity) do
    # Get inboxes of recipients ("to", "bto", "cc", "bcc" and "audience")
    with {:ok, activity_recipients} <- APUtils.get_recipients(activity) do
      # 1. When an object is being delivered to the originating actor's
      #    followers, a server MAY reduce the number of receiving actors
      #    delivered to by identifying all followers which share the same
      #    sharedInbox who would otherwise be individual recipients and
      #    instead deliver objects to said sharedInbox.

      # 2. If an object is addressed to the Public special collection, a
      #    server MAY deliver that object to all known sharedInbox endpoints
      #    on the network.
      {_public_recipients, non_public_recipients} =
        Enum.split_with(activity_recipients, &APUtils.public?(&1))

      # First check if the implemented database logic can return any inboxes
      # from our list of actor IRIs.
      {found_actors, found_inboxes} =
        Enum.reduce(non_public_recipients, [], fn actor_iri, acc ->
          case apply(database, :inbox_for_actor, [actor_iri]) do
            {:ok, %URI{} = inbox_iri} ->
              [{actor_iri, inbox_iri} | acc]

            _ ->
              acc
          end
        end)
        |> Enum.unzip()

      # For every actor we found an inbox for in the db, we should
      # remove it from the list of actors we still need to dereference
      case Enum.filter(non_public_recipients, fn actor_iri ->
             !Enum.member?(found_actors, actor_iri)
           end) do
        [] ->
          []

        actors_to_resolve ->
          # Look for any actors' inboxes that weren't already discovered above;
          # find these by making dereference calls to remote instances
          app_agent = Fedi.Application.app_agent()

          with {:ok, transport} <- apply(database, :new_transport, [outbox_iri, app_agent]),
               {:ok, max_depth} <-
                 Actor.delegate(context, :s2s, :max_delivery_recursion_depth, []),
               {:ok, remote_actors} <-
                 resolve_actors(database, transport, actors_to_resolve, 0, max_depth),
               {:ok, remote_inboxes} <- APUtils.get_inboxes(remote_actors) do
            remote_inboxes
          end
      end
      |> case do
        {:error, reason} ->
          {:error, reason}

        remote_inboxes ->
          # Combine this list of dereferenced inbox IRIs with the inboxes we already
          # found in the db, to make a complete list of target IRIs
          case found_inboxes ++ remote_inboxes do
            [] ->
              Logger.debug("No non-public recipients")
              {:error, "No non-public recipients"}

            targets ->
              # Verify the inbox on the sender.
              with {:ok, actor_iri} <- apply(database, :actor_for_outbox, [outbox_iri]),
                   {:ok, this_actor} <- apply(database, :get, [actor_iri]),
                   # Post-processing
                   {:get_inbox, %URI{} = ignore} <- {:get_inbox, APUtils.get_inbox(this_actor)} do
                case dedupe_iris(targets, [ignore]) do
                  [] ->
                    Logger.debug("No external recipients")
                    {:error, "No external recipients"}

                  recipients ->
                    activity = APUtils.strip_hidden_recipients(activity)
                    {:ok, context, activity, recipients}
                end
              else
                {:error, reason} -> {:error, reason}
                {:get_inbox, _} -> {:error, "No inbox for sender #{URI.to_string(outbox_iri)}"}
              end

              # end targets ->
          end

          # end remote_inboxes ->
      end
    end
  end

  def dedupe_iris(recipients, ignored) do
    ignored_set = MapSet.new(ignored)

    recipients
    |> MapSet.new()
    |> MapSet.delete(ignored_set)
    |> MapSet.to_list()
  end

  @doc """
  Takes a list of Actor id URIs and returns them as concrete
  instances of actor objects. It attempts to apply recursively when it encounters
  a target that is a Collection or OrderedCollection.

  If max_depth is zero or negative, then recursion is infinitely applied.

  If a recipient is a Collection or OrderedCollection, then the server MUST
  dereference the collection, WITH the user's credentials.

  Note that this also applies to CollectionPage and OrderedCollectionPage.
  """
  def resolve_actors(database, transport, actor_ids, depth, max_depth, acc \\ [])

  def resolve_actors(_database, _transport, [], 0, _max_depth, _acc) do
    {:error, "No actor ids to be resolved"}
  end

  def resolve_actors(
        database,
        transport,
        actor_ids,
        depth,
        max_depth,
        actors
      ) do
    if max_depth > 0 && depth >= max_depth do
      if Enum.empty?(actors) do
        {:error, "No actors resolved (depth #{max_depth} exceeded)"}
      else
        {:ok, actors}
      end
    else
      # TODO: Determine if more logic is needed here for inaccessible
      # collections owned by peer servers.
      {actors, more} =
        Enum.reduce(actor_ids, {actors, []}, fn iri, {actor_acc, coll_acc} = acc ->
          case dereference_for_resolving_inboxes(database, transport, iri) do
            {:ok, actor, []} ->
              {[actor | actor_acc], coll_acc}

            {:ok, _nil, more_ids} ->
              {actor_acc, coll_acc ++ more_ids}

            {:error, _} ->
              # Missing recipient -- skip.
              acc
          end
        end)

      more_count = Enum.count(more)

      if more_count == 0 do
        if Enum.empty?(actors) do
          actor_ids = Enum.map(actor_ids, &URI.to_string(&1)) |> Enum.join(", ")
          {:error, "No actors resolved from #{actor_ids}"}
        else
          {:ok, actors}
        end
      else
        # Recurse
        resolve_actors(database, transport, more, depth + 1, max_depth, actors)
      end
    end
  end

  @doc """
  Dereferences an IRI solely for finding an
  actor's inbox IRI to deliver to.

  The returned actor could be nil, if it wasn't an actor (ex: a Collection or
  OrderedCollection).
  """
  def dereference_for_resolving_inboxes(database, transport, %URI{} = actor_id) do
    with {:ok, m} <- apply(database, :dereference, [transport, actor_id]),
         {:ok, %{properties: properties} = actor} <-
           Fedi.Streams.JSONResolver.resolve(m) do
      # Attempt to see if the 'actor' is really some sort of type that has
      # an 'items' or 'orderedItems' property.
      ["items", "orderedItems"]
      |> Enum.reduce_while([], fn prop_name, acc ->
        case Map.get(properties, prop_name) do
          prop when is_struct(prop) ->
            case APUtils.to_id(prop) do
              %URI{} = id -> {:cont, [id | acc]}
              _ -> {:halt, {:error, "Actor #{prop_name} with no id"}}
            end

          _ ->
            {:cont, acc}
        end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        [] -> {:ok, actor, []}
        more_ids -> {:ok, nil, more_ids}
      end
    end
  end

  @doc """
  Takes a prepared Activity and send it to specific
  recipients on behalf of an actor.
  """
  def deliver_to_recipients(
        %{data: %{box_iri: inbox_iri, app_agent: app_agent}, database: database},
        activity,
        recipients
      )
      when is_list(recipients) do
    with {:ok, m} <- Fedi.Streams.Serializer.serialize(activity),
         {:ok, json_body} <- Jason.encode(m) do
      apply(database, :batch_deliver, [inbox_iri, app_agent, json_body, recipients])
    end
  end

  @doc """
  Adds the activity to the inbox at the specified IRI if
  the activity's ID has not yet been added to the inbox.

  It does not add the activity to this database's know federated data.

  Returns true when the activity is novel.
  """
  def add_to_inbox_if_new(%{database: database} = _context, %URI{} = inbox_iri, activity) do
    with {:activity_id, %URI{} = id} <- {:activity_id, Utils.get_json_ld_id(activity)},
         {:exists, {:ok, false}} <- {:exists, apply(database, :inbox_contains, [inbox_iri, id])},
         # It is a new id
         # Persist the activity
         {:ok, activity, _raw_json} <-
           apply(database, :create, [activity]),
         # Persist a reference to the activity in the inbox
         # Then return the the list of 'orderedItems'.
         {:ok, _ordered_collection_page} <-
           apply(database, :update_inbox, [inbox_iri, %{create: [activity]}]) do
      {:ok, true}
    else
      {:error, reason} ->
        {:error, reason}

      # If the inbox already contains the URL, early exit.
      {:exists, {:ok, _}} ->
        {:ok, false}

      {:activity_id, _} ->
        {:error, Utils.err_id_required(activity: activity)}
    end
  end

  @doc """
  Given an ActivityStreams value, recursively examines ownership of the id or
  href and the ones on properties applicable to inbox forwarding.

  Recursion may be limited by providing a 'max_depth' greater than zero. A
  value of zero or a negative number will result in infinite recursion.

  Ref: [AP Section 7.1.2](https://w3.org/TR/activitypub/#inbox-forwarding)
  Ref: The server SHOULD recurse through these values to look for linked objects
  owned by the server, and SHOULD set a maximum limit for recursion.
  """
  def has_inbox_forwarding_values(
        %{data: %{box_iri: box_iri, app_agent: _}, database: database} = context,
        %URI{} = inbox_iri,
        val,
        max_depth,
        curr_depth
      )
      when is_struct(val) do
    Logger.error("hi_fowarding_values inbox_iri #{URI.to_string(inbox_iri)}")
    Logger.error("hi_fowarding_values c.box_iri #{URI.to_string(box_iri)}")
    # Stop recurring if we are exceeding the maximum depth and the maximum
    # is a positive number.
    if max_depth > 0 && curr_depth >= max_depth do
      {:ok, false}
    else
      # Determine if we own the 'id' of any values on the properties we care
      # about.
      {types, iris} = APUtils.get_inbox_forwarding_values(val)

      cond do
        # For IRIs, simply check if we own them.
        owns_one_iri = owns_any_iri?(database, iris) ->
          case owns_one_iri do
            {:error, reason} -> {:error, reason}
            {:ok, true} -> {:ok, true}
          end

        # For embedded literals, check the id.
        owns_one_id = owns_any_id?(database, types) ->
          case owns_one_id do
            {:error, reason} -> {:error, reason}
            {:ok, true} -> {:ok, true}
          end

        # We must dereference the types
        true ->
          derefed_types = dereference_iris(context, iris)
          # Recurse
          owns_one_type =
            Enum.find(types ++ derefed_types, fn next_val ->
              has_inbox_forwarding_values(context, inbox_iri, next_val, max_depth, curr_depth + 1)
            end)

          case owns_one_type do
            {:error, reason} -> {:error, reason}
            {:ok, true} -> {:ok, true}
            _ -> {:ok, false}
          end
      end
    end
  end

  # For IRIs, simply check if we own them.
  def owns_any_iri?(database, iris) do
    Enum.find(iris, fn iri ->
      case apply(database, :owns, [iri]) do
        {:error, reason} -> {:error, reason}
        {:ok, true} -> {:ok, true}
        _ -> false
      end
    end)
  end

  # For embedded literals, check the id.
  def owns_any_id?(database, types) do
    Enum.find(types, fn as_value ->
      case Utils.get_json_ld_id(as_value) do
        %URI{} = id ->
          case apply(database, :owns, [id]) do
            {:error, reason} -> {:error, reason}
            {:ok, true} -> {:ok, true}
            _ -> false
          end

        _ ->
          {:error, "No id for type"}
      end
    end)
  end

  # Recursion preparation: Try fetching the IRIs so we can recurse into them.
  def dereference_iris(
        %{data: %{box_iri: box_iri, app_agent: app_agent}, database: database},
        iris
      ) do
    Enum.reduce(iris, [], fn iri, acc ->
      # Dereferencing the IRI.
      with {:ok, m} <- apply(database, :dereference, [box_iri, app_agent, iri]),
           {:ok, type} <- Fedi.Streams.JSONResolver.resolve(m) do
        [type | acc]
      else
        # Do not fail the entire process if the data is missing.
        # Do not fail the entire process if we cannot handle the type.
        {:error, _} -> acc
      end
    end)
  end

  @doc """
  Gets a new id from the database and then sets it on the object.

  Ref: [AP Section 6](https://www.w3.org/TR/activitypub/#client-to-server-interactions)
  If an Activity is submitted with a value in the id property,
  servers MUST ignore this and generate a new id for the Activity.
  """
  def set_object_id(%{database: database} = _context, object) do
    with {:ok, %URI{} = id} <- apply(database, :new_id, [object]) do
      Utils.set_json_ld_id(object, id)
    else
      {:error, reason} -> {:error, reason}
      value -> {:error, "Database did not return a URI: #{inspect(value)}"}
    end
  end

  @doc """
  Adds the side channel data to the context for Social API
  activity handlers.

  * `box_iri` is the outbox IRI that is handling this callback.
  * `app_agent` is the User-Agent string that will be used for
    dereferencing.
  * `raw_activity` is the JSON map literal received when deserializing the
    request body.
  * `undeliverable` is an out param, indicating if the handled activity
    should not be delivered to a peer. Its provided default value will always
    be used when a custom function is called.
  """
  def wrap_for_social_api(context, box_iri, raw_json) do
    app_agent = Fedi.Application.app_agent()

    struct(context,
      data:
        Map.merge(context.data || %{}, %{
          box_iri: box_iri,
          app_agent: app_agent,
          raw_activity: raw_json,
          undeliverable: false
        })
    )
  end

  @doc """
  Adds the side channel data to the context for Federated Protocol
  activity handlers.

  * `box_iri` is the inbox IRI that is handling this callback.
  * `app_agent` is the User-Agent string that will be used for
    dereferencing.
  * `on_follow` specifies which of the different default
    actions that the library can provide when receiving a Follow Activity
    from a peer, one of the following values:
  * `:do_nothing` does not take any action when a Follow Activity
    is received.
  * `:automatically_accept` triggers the side effect of sending an
    Accept of this Follow request in response.
  * `:automatically_reject` triggers the side effect of sending a
    Reject of this Follow request in response.
  """
  def wrap_for_federated_protocol(context, box_iri) do
    on_follow =
      case Actor.delegate(context, :s2s, :on_follow, []) do
        {:ok, value} when is_atom(value) -> value
        _ -> :do_nothing
      end

    app_agent = Fedi.Application.app_agent()

    struct(context,
      data:
        Map.merge(context.data || %{}, %{
          box_iri: box_iri,
          app_agent: app_agent,
          on_follow: on_follow
        })
    )
  end
end
