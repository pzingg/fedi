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
  alias Fedi.ActivityPub.HTTPSignatureTransport

  @enforce_keys [:common]
  defstruct [
    :common,
    :c2s,
    :s2s,
    :c2s_resolver,
    :s2s_resolver,
    :fallback,
    :database,
    :enable_social_protocol,
    :enable_federated_protocol,
    :data
  ]

  @type t() :: %__MODULE__{
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          c2s_resolver: module() | nil,
          s2s_resolver: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          enable_social_protocol: boolean(),
          enable_federated_protocol: boolean(),
          data: term()
        }

  # Same as above but just a map
  @type context() :: %{
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          c2s_resolver: module() | nil,
          s2s_resolver: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          enable_social_protocol: boolean(),
          enable_federated_protocol: boolean(),
          data: term()
        }

  def new(common, opts \\ []) do
    opts =
      Keyword.merge(
        [
          c2s_resolver: Fedi.ActivityPub.SocialCallbacks,
          s2s_resolver: Fedi.ActivityPub.FederatingCallbacks
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
          {:ok, {conn, !unauthorized}}

        {:error, :callback_not_found} ->
          {:ok, {conn, true}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:activity_actor, _} -> {:error, "No Actor in posting activity"}
    end
  end

  @doc """
  Handles the side effects of determining whether to block the peer's
  request, adding the activity to the actor's inbox, and triggering side
  effects based on the activity's type.
  """
  def post_inbox(context, %URI{} = inbox_iri, activity) do
    case add_to_inbox_if_new(context, inbox_iri, activity) do
      {:error, reason} ->
        {:error, reason}

      {:ok, false} ->
        :ok

      {:ok, true} ->
        if Actor.protocol_supported?(context, :s2s) do
          # Wrapped data for FederatingCallbacks
          on_follow =
            case Actor.delegate(context, :s2s, :on_follow, []) do
              {:ok, value} when is_atom(value) -> value
              _ -> :do_nothing
            end

          context = %{context | data: %{inbox_iri: inbox_iri, on_follow: on_follow}}

          case Actor.resolver_callback(context, :s2s, activity, top_level: true) do
            {:error, reason} -> {:error, reason}
            _ -> {:ok, {activity, context.data}}
          end
        end
    end
  end

  @doc """
  Implements the 3-part inbox forwarding algorithm specified in
  the ActivityPub specification. Does not modify the Activity, but may send
  outbound requests as a side effect.

  Sets the federated data in the database.

  Ref: [Section 7.1.2](https://w3.org/TR/activitypub/#inbox-forwarding)
  """
  def inbox_forwarding(%{database: database} = context, %URI{} = inbox_iri, activity) do
    # Ref: This is the first time the server has seen this Activity.
    with {:get_id, %URI{} = id} <-
           {:get_id, Utils.get_json_ld_id(activity)},
         # See if we have seen the activity
         {:exists, {:ok, false}} <-
           {:exists, apply(database, :exists, [id])},
         # Attempt to create the activity entry.
         {:ok, _} <-
           apply(database, :create, [activity]),
         # Ref: The values of 'to', 'cc', or 'audience' are Collections owned by this server.
         {:ok, my_iris} <-
           owned_recipients(database, activity),
         # Finally, load our IRIs to determine if they are a Collection or
         # OrderedCollection.
         {:ok, {col_iris, cols, ocols}} <-
           get_collection_types(database, my_iris) do
      # If we own none of the Collection IRIs in 'to', 'cc', or 'audience'
      # then no need to do inbox forwarding. We have nothing to forward to.
      if Enum.empty?(col_iris) do
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
              deliver_to_recipients(context, inbox_iri, activity, recipients)
            end

            # else {:error, reason}
          end
        end
      end
    else
      # We have seen the activity before
      {:exists, {:ok, true}} -> :ok
      {:error, reason} -> {:error, reason}
      {step, result} -> {:error, "Internal error at step #{step}: #{inspect(result)}"}
    end
  end

  @doc """
  Finds all IRIs of 'to', 'cc', or 'audience' that are owned by this server.
  We need to find all of them so that forwarding can properly occur.
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
      {:error, reason} -> {:error, reason}
      result -> {:ok, result}
    end
  end

  @doc """
  Filter the list of collection ids, then gather the ids contained
  within the collections.
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
        # Wrapped data for SocialCallbacks
        context = %{
          context
          | data: %{outbox_iri: outbox_iri, raw_activity: raw_json, undeliverable: false}
        }

        case Actor.resolver_callback(context, :c2s, activity, top_level: true) do
          {:ok, {new_actor, new_activity}} -> {new_actor, new_activity}
          _ -> {context, activity}
        end
      else
        {context, activity}
      end

    add_to_outbox(context, outbox_iri, activity)
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
  def deliver(context, %URI{} = outbox, activity) do
    with {:ok, activity, recipients} <- prepare(context, outbox, activity) do
      deliver_to_recipients(context, outbox, activity, recipients)
    end
  end

  @doc """
  Wraps an object with a Create activity.
  """
  def wrap_in_create(%{database: database} = _context, activity, %URI{} = outbox_iri) do
    with {:ok, actor_iri} <- apply(database, :actor_for_outbox, [outbox_iri]) do
      APUtils.wrap_in_create(activity, actor_iri)
    end
  end

  ### Implementation details

  @doc """
  Adds the activity to the outbox and creates the activity in the
  internal database as its own entry.
  """
  def add_to_outbox(%{database: database} = context, %URI{} = outbox_iri, activity) do
    with {:get_id, %URI{} = _id} <- {:get_id, Utils.get_json_ld_id(activity)},
         # Persist the activity
         {:create, {:ok, {activity, _json}}} <-
           {:create, apply(database, :create, [activity])},
         # Persist a reference to the activity in the outbox
         # Then return the the list of 'orderedItems'.
         {:database, {:ok, _ordered_collection_page}} <-
           {:database, apply(database, :update_outbox, [outbox_iri, %{create: [activity]}])} do
      {:ok, {activity, context.data}}
    else
      {:get_id, _} ->
        {:error, "Activity does not have an id"}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Takes a deliverable object and returns a list of the proper recipient
  target URIs. Additionally, the deliverable object will have any hidden
  hidden recipients ("bto" and "bcc") stripped from it.

  Only called if both the Social API and Federated Protocol are supported.
  """
  def prepare(%{database: database} = context, %URI{} = outbox_iri, %{properties: _} = activity) do
    with {:ok, recipients} <- APUtils.get_recipients(activity) do
      # 1. When an object is being delivered to the originating actor's
      #    followers, a server MAY reduce the number of receiving actors
      #    delivered to by identifying all followers which share the same
      #    sharedInbox who would otherwise be individual recipients and
      #    instead deliver objects to said sharedInbox.
      # 2. If an object is addressed to the Public special collection, a
      #    server MAY deliver that object to all known sharedInbox endpoints
      #    on the network.
      recipients = Enum.filter(recipients, fn actor_iri -> !APUtils.public?(actor_iri) end)

      # First check if the implemented database logic can return any inboxes
      # from our list of actor IRIs.
      {_inboxes, actors_with_inboxes} =
        Enum.reduce(recipients, [], fn actor_iri, acc ->
          case apply(database, :inbox_for_actor, [actor_iri]) do
            {:ok, %URI{} = inbox_iri} ->
              [{inbox_iri, actor_iri} | acc]

            _ ->
              acc
          end
        end)
        |> Enum.unzip()

      # For every actor we found an inbox for in the db, we should
      # remove it from the list of actors we still need to dereference
      recipients =
        Enum.filter(recipients, fn actor_iri -> !Enum.member?(actors_with_inboxes, actor_iri) end)

      # Look for any actors' inboxes that weren't already discovered above;
      # find these by making dereference calls to remote instances
      transport = HTTPSignatureTransport.new(context, outbox_iri)

      with {:ok, max_depth} <- Actor.delegate(context, :s2s, :max_delivery_recursion_depth, []),
           {:ok, remote_actors} <- resolve_actors(context, transport, recipients, 0, max_depth),
           {:ok, remote_inboxes} <- APUtils.get_inboxes(remote_actors),
           # Combine this list of dereferenced inbox IRIs with the inboxes we already
           # found in the db, to make a complete list of target IRIs
           targets <- remote_actors ++ remote_inboxes,
           # Get inboxes of sender.
           {:ok, actor_iri} <- apply(database, :actor_for_outbox, [outbox_iri]),
           {:ok, this_actor} <- apply(database, :get, [actor_iri]),
           # Post-processing
           {:get_inbox, %URI{} = _ignore} <- {:get_inbox, APUtils.get_inbox(this_actor)} do
        recipients = MapSet.new(targets) |> MapSet.to_list()
        activity = APUtils.strip_hidden_recipients(activity)
        {:ok, activity, recipients}
      else
        {:get_inbox, _} -> {:error, "Actor for #{URI.to_string(outbox_iri)} has no inbox"}
        {:error, reason} -> {:error, reason}
      end
    end
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
  def resolve_actors(context, transport, actor_ids, depth, max_depth, actors \\ []) do
    if max_depth > 0 && depth >= max_depth do
      {:ok, actors}
    else
      # TODO: Determine if more logic is needed here for inaccessible
      # collections owned by peer servers.
      {actors, more} =
        Enum.reduce(actor_ids, {actors, []}, fn iri, {actor_acc, coll_acc} = acc ->
          case dereference_for_resolving_inboxes(transport, iri) do
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
        {:ok, actors}
      else
        # Recurse
        Logger.error("resolve_actors #{depth + 1} for an additional #{more_count} items")
        resolve_actors(context, transport, more, depth + 1, max_depth, actors)
      end
    end
  end

  @doc """
  Dereferences an IRI solely for finding an
  actor's inbox IRI to deliver to.

  The returned actor could be nil, if it wasn't an actor (ex: a Collection or
  OrderedCollection).
  """
  def dereference_for_resolving_inboxes(transport, %URI{} = actor_id) do
    with {:ok, json_body} <-
           HTTPSignatureTransport.dereference(transport, actor_id),
         {:ok, %{properties: properties} = actor} <-
           Fedi.Streams.JSONResolver.resolve(json_body) do
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
  def deliver_to_recipients(context, %URI{} = box_iri, activity, recipients)
      when is_list(recipients) do
    with {:ok, m} <- Fedi.Streams.Serializer.serialize(activity),
         {:ok, json_body} <- Jason.encode(m),
         transport <- HTTPSignatureTransport.new(context, box_iri) do
      HTTPSignatureTransport.batch_deliver(transport, json_body, recipients)
    end
  end

  @doc """
  Adds the activity to the inbox at the specified IRI if
  the activity's ID has not yet been added to the inbox.

  It does not add the activity to this database's know federated data.

  Returns true when the activity is novel.
  """
  def add_to_inbox_if_new(%{database: database} = _context, %URI{} = inbox_iri, activity) do
    with %URI{} = id <- Utils.get_json_ld_id(activity),
         {:ok, false} <- apply(database, :inbox_contains, [inbox_iri, id]) do
      # It is a new id, acquire the inbox.
      update_inbox = fn inbox ->
        oi =
          Utils.get_ordered_items(inbox) ||
            Utils.new_ordered_items()

        oi = Fedi.Streams.PropertyIterator.prepend_iri(oi, id)
        Utils.set_ordered_items(inbox, oi)
      end

      apply(database, :update_inbox, [inbox_iri, update_inbox])
    else
      # If the inbox already contains the URL, early exit.
      {:ok, true} -> {:ok, false}
      {:error, reason} -> {:error, reason}
      nil -> {:error, "Activity does not have an id"}
    end
  end

  @doc """
  Given an ActivityStreams value, recursively examines ownership of the id or
  href and the ones on properties applicable to inbox forwarding.

  Recursion may be limited by providing a 'max_depth' greater than zero. A
  value of zero or a negative number will result in infinite recursion.

  Ref: [Section 7.1.2](https://w3.org/TR/activitypub/#inbox-forwarding)
  Ref: The server SHOULD recurse through these values to look for linked objects
  owned by the server, and SHOULD set a maximum limit for recursion.
  """
  def has_inbox_forwarding_values(
        %{database: database} = context,
        %URI{} = inbox_iri,
        val,
        max_depth,
        curr_depth
      )
      when is_struct(val) do
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
          derefed_types = dereference_iris(context, iris, inbox_iri)
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
  def dereference_iris(context, iris, inbox_iri) do
    Enum.reduce(iris, [], fn iri, acc ->
      with transport <- HTTPSignatureTransport.new(context, inbox_iri),
           # Dereferencing the IRI.
           {:ok, json_body} <- HTTPSignatureTransport.dereference(transport, iri),
           {:ok, type} <- Fedi.Streams.JSONResolver.resolve(json_body) do
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
  """
  def set_object_id(%{database: database} = _context, object) do
    with {:ok, %URI{} = id} <- apply(database, :new_id, [object]) do
      Utils.set_json_ld_id(object, id)
    else
      {:error, reason} -> {:error, reason}
      value -> {:error, "Database did not return a URI: #{inspect(value)}"}
    end
  end
end
