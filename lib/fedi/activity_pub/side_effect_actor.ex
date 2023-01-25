defmodule Fedi.ActivityPub.SideEffectActor do
  @moduledoc """
  Handles the implementation side effects presented in the ActivityPub
  specification, but requires a more opinionated application to be written.

  Note that when using the `SideEffectActor` with an application that good-faith
  implements its required interfaces, the ActivityPub specification is
  guaranteed to be correctly followed.
  """

  @behaviour Fedi.ActivityPub.ActorBehavior

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityPub.ActorFacade
  alias Fedi.ActivityPub.Utils, as: APUtils

  @enforce_keys [:common, :database, :app_agent]
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
    :current_user,
    :app_agent,
    :box_iri,
    :raw_activity,
    deliverable: true,
    on_follow: :do_nothing,
    data: %{}
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
          current_user: ActorFacade.current_user(),
          app_agent: String.t(),
          box_iri: URI.t() | nil,
          raw_activity: map() | nil,
          deliverable: boolean(),
          on_follow: ActorFacade.on_follow(),
          data: map()
        }

  # Same as above but just a map
  @type context() :: ActorFacade.context()

  @doc """
  Builds a `SideEffectActor` struct, plugging in modules for the delegates and
  activity handlers.

  * `common` - the Elixir module implementing the
    `CommonApi` behaviour used by both the Social API and Federated Protocol.
  * `database` - the Elixir module implementing the `DatabaseApi` behaviour.
  * `opts` - Keyword list specifying the Elixir modules that implement the
     Social API and Federated Protocols. `opts` uses these keys:
  * `:c2s` (optional) - the Elixir module implementing the `SocialApi`
     behaviour.
  * `:s2s` (optional) - the Elixir module implementing the `FederatingApi`
     behaviour.

  The `:c2s_activity_handler` and `:s2s_activity_handler` members
  are set to the built-in values `SocialActivityHandler` and
  `FederatingActivityHandler` respectively.
  """
  def new(common, database, opts \\ []) do
    opts =
      Keyword.merge(
        [
          c2s_activity_handler: Fedi.ActivityPub.SocialActivityHandler,
          s2s_activity_handler: Fedi.ActivityPub.FederatingActivityHandler
        ],
        opts
      )

    Fedi.ActivityPub.Actor.make_actor(__MODULE__, common, database, opts)
  end

  @doc """
  Defers to the S2S delegate.
  """
  @impl true
  def post_inbox_request_body_hook(context, %Plug.Conn{} = conn, activity) do
    ActorFacade.post_inbox_request_body_hook(context, conn, activity)
  end

  @doc """
  Defers to the C2S delegate.
  """
  @impl true
  def post_outbox_request_body_hook(context, %Plug.Conn{} = conn, activity) do
    ActorFacade.post_outbox_request_body_hook(context, conn, activity)
  end

  @doc """
  Defers to the S2S delegate to authenticate the request.
  """
  @impl true
  def authenticate_post_inbox(context, %Plug.Conn{} = conn) do
    ActorFacade.authenticate_post_inbox(context, conn)
  end

  @doc """
  Defers to the common delegate to authenticate the request.
  """
  @impl true
  def authenticate_get_inbox(context, %Plug.Conn{} = conn) do
    ActorFacade.authenticate_get_inbox(context, conn)
  end

  @doc """
  Defers to the C2S delegate to authenticate the request.
  """
  @impl true
  def authenticate_post_outbox(context, %Plug.Conn{} = conn) do
    ActorFacade.authenticate_post_outbox(context, conn)
  end

  @doc """
  Defers to the common delegate to authenticate the request.
  """
  @impl true
  def authenticate_get_outbox(context, %Plug.Conn{} = conn) do
    ActorFacade.authenticate_get_outbox(context, conn)
  end

  @doc """
  Defers to the federating protocol whether the peer request
  is authorized based on the actors' ids.
  """
  @impl true
  def authorize_post_inbox(context, %Plug.Conn{} = conn, activity)
      when is_struct(activity) do
    with {:activity_actor, %P.Actor{values: [_ | _]} = actor_prop} <-
           {:activity_actor, Utils.get_actor(activity)},
         {:ok, actor_ids} <- APUtils.get_ids(actor_prop) do
      # Determine if the actor(s) sending this request are blocked.
      case ActorFacade.blocked(context, actor_ids) do
        {:ok, unauthorized} ->
          {:ok, conn, !unauthorized}

        {:error, :callback_not_found} ->
          {:ok, conn, true}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_actor, _} -> Utils.err_actor_required(activity: activity)
    end
  end

  @doc """
  Handles the side effects of determining whether to block the peer's
  request, adding the activity to the actor's inbox, and triggering side
  effects based on the activity's type.
  """
  @impl true
  def post_inbox(context, %URI{} = inbox_iri, activity)
      when is_struct(context) and is_struct(activity) do
    case add_to_inbox_if_new(context, inbox_iri, activity) do
      {:error, reason} ->
        {:error, reason}

      {:ok, false} ->
        # Already in our inbox, all good
        :ok

      {:ok, true} ->
        # A new activity was added to the inbox
        if ActorFacade.protocol_supported?(context, :s2s) do
          context = wrap_for_federated_protocol(context, inbox_iri)

          case ActorFacade.handle_s2s_activity(context, activity, top_level: true) do
            {:error, reason} -> {:error, reason}
            _ -> :ok
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
  @impl true
  def inbox_forwarding(context, %URI{} = inbox_iri, activity) do
    # Ref: This is the first time the server has seen this Activity.
    case Utils.get_json_ld_id(activity) do
      %URI{} = id ->
        # See if we have seen the activity
        with {:exists?, {:ok, false}} <-
               {:exists?, ActorFacade.db_exists?(context, id)},
             # Attempt to create the activity entry.
             {:ok, _created, _raw_json} <-
               ActorFacade.db_create(context, activity),
             # Ref: The values of 'to', 'cc', or 'audience' are Collections owned by this server.
             {:ok, my_iris} <-
               owned_recipients(context, activity),
             # Finally, load our IRIs to determine if they are a Collection or
             # OrderedCollection.
             {:ok, col_iris, cols, ocols} <-
               get_collection_types(context, my_iris) do
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
                   ActorFacade.max_inbox_forwarding_recursion_depth(context),
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
            Logger.error("Inbox forwarding error for #{id}: #{reason}")
            {:error, reason}

          # We have seen the activity before
          {:exists?, {:ok, _}} ->
            Logger.debug("No inbox forwarding needed: #{id} has been seen")
            :ok
        end

      nil ->
        {:error, Utils.err_id_required(activity: activity)}
    end
  end

  @doc """
  Finds all IRIs of 'to', 'cc', or 'audience' that are owned by this server.
  We need to find all of them so that forwarding can properly occur.

  Ref: [AP Section 7.1.1](https://www.w3.org/TR/activitypub/#outbox-delivery)
  When objects are received in the outbox (for servers which support both
  Client to Server interactions and Server to Server Interactions), the
  server MUST target and deliver to:

  The 'to', 'bto', 'cc', 'bcc' or 'audience' fields if their values are individuals
  or Collections owned by the actor.
  """
  def owned_recipients(context, activity) do
    with {:ok, recipients} <- APUtils.get_recipients(activity, which: :direct_only) do
      Enum.reduce_while(recipients, [], fn iri, acc ->
        case ActorFacade.db_owns?(context, iri) do
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
  Loads the recipient IRIs and separates them into OrderedCollection and
  Collection values.
  """
  def get_collection_types(context, iris) do
    # Load the unfiltered IRIs.
    Enum.reduce_while(iris, {[], %{}, %{}}, fn iri, {iri_acc, col_acc, ocol_acc} = acc ->
      case ActorFacade.db_get(context, iri) do
        {:error, reason} ->
          {:halt, {:error, reason}}

        {:ok, as_value} ->
          cond do
            APUtils.is_or_extends?(as_value, "OrderedCollection") ->
              {:cont, {[iri | iri_acc], col_acc, Map.put(ocol_acc, iri, as_value)}}

            APUtils.is_or_extends?(as_value, "Collection") ->
              {:cont, {[iri | iri_acc], Map.put(col_acc, iri, as_value), ocol_acc}}

            true ->
              Logger.debug(
                "Owned recipient #{iri} is a #{Utils.alias_module(as_value.__struct__)}, neither an OrderedCollection nor a Collection"
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
  Filters the list of collection ids, and then gathers the ids contained
  within the collections.

  Ref: [AP Section 7.1.1](https://www.w3.org/TR/activitypub/#outbox-delivery)
  When objects are received in the outbox (for servers which support both
  Client to Server interactions and Server to Server Interactions), the
  server MUST target and deliver to:

  The 'to', 'bto', 'cc', 'bcc' or 'audience' fields if their values are individuals
  or Collections owned by the actor.
  """
  def get_collection_recipients(context, col_iris, cols, ocols, activity) do
    case ActorFacade.filter_forwarding(context, col_iris, activity) do
      {:error, reason} ->
        {:error, reason}

      {:ok, to_send} ->
        Enum.reduce_while(to_send, [], fn iri, acc ->
          cond do
            %{properties: %{"items" => prop}} = Map.get(cols, iri) ->
              case APUtils.to_id(prop) do
                %URI{} = id -> {:cont, [id | acc]}
                _ -> {:halt, {:error, Utils.err_id_required(activity: activity)}}
              end

            %{properties: %{"orderedItems" => prop}} = Map.get(ocols, iri) ->
              case APUtils.to_id(prop) do
                %URI{} = id -> {:cont, [id | acc]}
                _ -> {:halt, {:error, Utils.err_id_required(activity: activity)}}
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
  @impl true
  def post_outbox(context, activity, %URI{} = outbox_iri, raw_json) do
    with true <- ActorFacade.protocol_supported?(context, :c2s),
         context <- wrap_for_social_api(context, outbox_iri, raw_json),
         {:ok, activity, deliverable} <-
           ActorFacade.handle_c2s_activity(context, activity, top_level: true) do
      {activity, deliverable}
    else
      {:error, reason} ->
        {:error, reason}

      _ ->
        {activity, true}
    end
    |> case do
      {:error, reason} ->
        {:error, reason}

      {activity, deliverable} ->
        case add_to_outbox(context, outbox_iri, activity) do
          {:ok, _} -> {:ok, deliverable}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Creates new 'id' entries on an activity and its objects if it is a
  Create activity.
  """
  @impl true
  def add_new_ids(context, activity) do
    case set_object_id(context, activity) do
      {:ok, activity} ->
        if APUtils.is_or_extends?(activity, "Create") do
          case APUtils.get_actor_id(activity, context) do
            {:ok, actor_id} ->
              APUtils.update_objects(activity, fn object ->
                set_object_attributed_to_and_id(context, actor_id, object)
              end)

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:ok, activity}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Completes the peer-to-peer sending of a federated message to
  another server.

  Called if the Federated Protocol is supported.
  """
  @impl true
  def deliver(context, outbox_iri, activity) do
    with {:ok, context, activity, recipients} <- prepare(context, outbox_iri, activity) do
      wrap_for_federated_protocol(context, outbox_iri)
      |> deliver_to_recipients(activity, recipients)
    end
  end

  @doc """
  Wraps an object with a Create activity.
  """
  @impl true
  def wrap_in_create(context, activity, %URI{} = outbox_iri) do
    with {:ok, actor_iri} <- ActorFacade.db_actor_for_outbox(context, outbox_iri) do
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
  def add_to_outbox(context, %URI{} = outbox_iri, activity)
      when is_struct(activity) do
    with {:activity_id, %URI{} = _id} <- {:activity_id, Utils.get_json_ld_id(activity)},
         # Persist the activity
         {:ok, activity, _raw_json} <-
           ActorFacade.db_create(context, activity),
         # Persist a reference to the activity in the outbox
         # Then return the the list of 'orderedItems'.
         {:ok, _ordered_collection_page} <-
           ActorFacade.db_update_collection(context, outbox_iri, %{add: [activity]}) do
      {:ok, activity}
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
  hidden recipients ('bto' and 'bcc' properties) stripped from it.

  Only called if both the Social API and Federated Protocol are supported.
  """
  def prepare(context, %URI{} = outbox_iri, %{properties: _} = activity) do
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
          case ActorFacade.db_inbox_for_actor(context, actor_iri) do
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
          with {:ok, transport} <- ActorFacade.db_new_transport(context),
               {:ok, max_depth} <-
                 ActorFacade.max_delivery_recursion_depth(context),
               {:ok, remote_actors} <-
                 resolve_actors(context, transport, actors_to_resolve, 0, max_depth),
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
              {:ok, context, activity, []}

            targets ->
              # Verify the inbox on the sender.
              with {:ok, actor_iri} <- ActorFacade.db_actor_for_outbox(context, outbox_iri),
                   {:ok, this_actor} <- ActorFacade.db_get(context, actor_iri),
                   # Post-processing
                   {:get_inbox, %URI{} = ignore} <- {:get_inbox, APUtils.get_inbox(this_actor)} do
                case dedupe_iris(targets, [ignore]) do
                  [] ->
                    Logger.debug("No external recipients")
                    {:error, "No external recipients"}

                  recipients ->
                    activity = APUtils.strip_hidden_recipients(activity)
                    # Logger.debug("prepare #{Utils.get_json_ld_id(activity)}")
                    {:ok, context, activity, recipients}
                end
              else
                {:error, reason} -> {:error, reason}
                {:get_inbox, _} -> {:error, "No inbox for sender #{outbox_iri}"}
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
  def resolve_actors(context, transport, actor_ids, depth, max_depth, acc \\ [])

  def resolve_actors(_context, _transport, [], 0, _max_depth, _acc) do
    {:error, "No actor ids to be resolved"}
  end

  def resolve_actors(
        context,
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
      # TODO Determine if more logic is needed here for inaccessible
      # collections owned by peer servers
      {actors, more} =
        Enum.reduce(actor_ids, {actors, []}, fn iri, {actor_acc, coll_acc} = acc ->
          case dereference_for_resolving_inboxes(context, transport, iri) do
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
        resolve_actors(context, transport, more, depth + 1, max_depth, actors)
      end
    end
  end

  @doc """
  Dereferences an IRI solely for finding an actor's inbox IRI to deliver to.

  The returned actor could be nil, if it wasn't an actor (ex: a Collection or
  OrderedCollection).
  """
  def dereference_for_resolving_inboxes(context, transport, %URI{} = actor_id) do
    with {:ok, m} <- ActorFacade.db_dereference(context, transport, actor_id),
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
  Takes a prepared Activity and send it to specific recipients on behalf
  of an actor.
  """
  def deliver_to_recipients(
        %{box_iri: %URI{}} = context,
        activity,
        recipients
      )
      when is_list(recipients) do
    with {:ok, m} <- Fedi.Streams.Serializer.serialize(activity),
         :ok <- APUtils.verify_no_hidden_recipients(m, "activity"),
         {:ok, json_body} <- Jason.encode(m) do
      ActorFacade.db_batch_deliver(context, json_body, recipients)
    end
  end

  @doc """
  Adds the activity to the inbox at the specified IRI if
  the activity's ID has not yet been added to the inbox.

  It does not add the activity to this database's know federated data.

  Returns true when the activity is novel.
  """
  def add_to_inbox_if_new(context, %URI{} = inbox_iri, activity) do
    with {:activity_id, %URI{} = id} <- {:activity_id, Utils.get_json_ld_id(activity)},
         {:exists?, {:ok, false}} <-
           {:exists?, ActorFacade.db_collection_contains?(context, inbox_iri, id)},
         # It is a new id
         # Persist the activity
         {:ok, activity, _raw_json} <-
           ActorFacade.db_create(context, activity),
         # Persist a reference to the activity in the inbox
         # Then return the the list of 'orderedItems'.
         {:ok, _ordered_collection_page} <-
           ActorFacade.db_update_collection(context, inbox_iri, %{add: [activity]}) do
      {:ok, true}
    else
      {:error, reason} ->
        {:error, reason}

      # If the inbox already contains the URL, early exit.
      {:exists?, {:ok, _}} ->
        {:ok, false}

      {:activity_id, _} ->
        {:error, Utils.err_id_required(activity: activity)}
    end
  end

  @doc """
  Given an ActivityStreams value, recursively examines ownership of the id or
  href and the ones on properties applicable to inbox forwarding.

  Recursion may be limited by providing a `max_depth` greater than zero. A
  value of zero or a negative number will result in infinite recursion.

  Ref: [AP Section 7.1.2](https://w3.org/TR/activitypub/#inbox-forwarding)
  Ref: The server SHOULD recurse through these values to look for linked objects
  owned by the server, and SHOULD set a maximum limit for recursion.
  """
  def has_inbox_forwarding_values(
        %{box_iri: box_iri} = context,
        %URI{} = inbox_iri,
        val,
        max_depth,
        curr_depth
      )
      when is_struct(val) do
    # QUESTION Are these two values always the same?
    # Could we eliminate the inbox_iri argument?
    Logger.error("hi_fowarding_values inbox_iri #{inbox_iri}")
    Logger.error("hi_fowarding_values c.box_iri #{box_iri}")

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
        owns_one_iri = owns_any_iri?(context, iris) ->
          case owns_one_iri do
            {:error, reason} -> {:error, reason}
            {:ok, true} -> {:ok, true}
          end

        # For embedded literals, check the id.
        owns_one_id = owns_any_id?(context, types) ->
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
  def owns_any_iri?(context, iris) do
    Enum.find(iris, fn iri ->
      case ActorFacade.db_owns?(context, iri) do
        {:error, reason} -> {:error, reason}
        {:ok, true} -> {:ok, true}
        _ -> false
      end
    end)
  end

  # For embedded literals, check the id.
  def owns_any_id?(context, types) do
    Enum.find(types, fn as_value ->
      case Utils.get_json_ld_id(as_value) do
        %URI{} = id ->
          case ActorFacade.db_owns?(context, id) do
            {:error, reason} -> {:error, reason}
            {:ok, true} -> {:ok, true}
            _ -> false
          end

        _ ->
          {:error, "No id for type"}
      end
    end)
  end

  @doc """
  Recursion preparation: Try fetching the IRIs so we can recurse into them.
  """
  def dereference_iris(
        %{box_iri: _box_iri, app_agent: _app_agent} = context,
        iris
      ) do
    Enum.reduce(iris, [], fn iri, acc ->
      # Dereferencing the IRI.
      with {:ok, m} <- ActorFacade.db_dereference(context, iri),
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
  def set_object_id(context, object) do
    with {:ok, %URI{} = id} <- ActorFacade.db_new_id(context, object) do
      Utils.set_json_ld_id(object, id)
    end
  end

  def set_object_attributed_to_and_id(context, %URI{} = actor_id, object) do
    # FIXME This will happen later in SocialActivityHandler.create
    # but db_new_id requires an actor to build the id.
    # Perhaps take it out of the context instead?
    object =
      if Utils.get_iri(object, "attributedTo") do
        object
      else
        Utils.set_iri(object, "attributedTo", actor_id)
      end

    with {:ok, %URI{} = id} <- ActorFacade.db_new_id(context, object) do
      Utils.set_json_ld_id(object, id)
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
  * `deliverable` is an out param, indicating if the handled activity
    should be delivered to a peer. Its provided default value will always
    be used when a custom function is called.
  """
  def wrap_for_social_api(context, box_iri, raw_json) do
    struct(context,
      box_iri: box_iri,
      raw_activity: raw_json,
      deliverable: true
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
      case ActorFacade.on_follow(context) do
        {:ok, value} when is_atom(value) -> value
        _ -> :do_nothing
      end

    struct(context,
      box_iri: box_iri,
      on_follow: on_follow
    )
  end
end
