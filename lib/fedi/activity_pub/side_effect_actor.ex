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
    :new_activity_id,
    :request_signed_by,
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
          new_activity_id: URI.t() | nil,
          request_signed_by: URI.t() | nil,
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
  def post_outbox_request_body_hook(context, activity) do
    ActorFacade.post_outbox_request_body_hook(context, activity)
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
        {:ok, true} ->
          {:ok, conn, false}

        {:ok, false} ->
          ActorFacade.authorize_post_inbox(context, conn, activity)

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
      {:activity_actor, _} -> {:error, Utils.err_actor_required(activity: activity)}
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

      {:ok, nil} ->
        # Already in our inbox, all good
        {:ok, context}

      {:ok, %URI{} = activity_id} ->
        # A new activity was added to the inbox
        if ActorFacade.protocol_supported?(context, :s2s) do
          context = wrap_for_federated_protocol(context, inbox_iri, activity_id)

          case ActorFacade.handle_s2s_activity(context, activity, top_level: true) do
            {:error, reason} -> {:error, reason}
            _ -> {:ok, context}
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
    # See if we have seen the activity
    with {:seen?, {:ok, false, _id}} <-
           {:seen?, activity_seen?(context, activity)},
         # Attempt to create the activity entry.
         {:ok, _created, _raw_json} <-
           ActorFacade.db_create(context, activity),
         # Ref: The values of 'to', 'cc', or 'audience' are Collections owned by this server.
         {:ok, my_iris} <-
           owned_recipients(context, activity),
         # Finally, load our IRIs to determine if they are a Collection or
         # OrderedCollection.
         {:ok, col_iris, cols, ocols} <-
           get_collection_types(context, my_iris),
         {:has_collection?, true} <-
           {:has_collection?, !Enum.empty?(col_iris)},
         # Ref: The values of 'inReplyTo', 'object', 'target' and/or 'tag' are objects owned by the server.
         # The server SHOULD recurse through these values to look for linked objects
         # owned by the server, and SHOULD set a maximum limit for recursion.
         # This is only a boolean trigger: As soon as we get
         # a hit that we own something, then we should do inbox forwarding.
         {:ok, max_depth} <-
           ActorFacade.max_inbox_forwarding_recursion_depth(context),
         # If we don't own any of the 'inReplyTo', 'object', 'target', or 'tag'
         # values, then no need to do inbox forwarding.
         {:owned?, true} <-
           {:owned?, has_inbox_forwarding_values?(context, inbox_iri, activity, max_depth, 0)},
         # Do the inbox forwarding since the above conditions hold true. Support
         # the behavior of letting the application filter out the resulting
         # collections to be targeted.
         {:ok, recipients} <-
           get_collection_recipients(context, col_iris, cols, ocols, activity),
         {:ok, recipients} <-
           inboxes_for_recipients(context, recipients, inbox_iri),
         _ <-
           Logger.error(
             "Inbox forwarding to #{inspect(Enum.map(recipients, &URI.to_string(&1)))}"
           ),
         {:ok, _count} <- deliver_to_recipients(context, activity, recipients) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Inbox forwarding error: #{reason}")
        {:error, reason}

      # We have seen the activity before
      {:seen?, {:ok, _, id}} ->
        Logger.debug("No inbox forwarding needed: #{id} has been seen")
        :ok

      {:has_collection?, _} ->
        Logger.debug("No inbox fowarding needed: no collections in recipients")
        :ok

      {:owned?, _} ->
        Logger.debug("No inbox forwarding needed: no ownership of reference")
        :ok
    end
  end

  def activity_seen?(%{new_activity_id: new_id} = context, activity) do
    case Utils.get_json_ld_id(activity) do
      %URI{} = id ->
        if id == new_id do
          Logger.debug("seen?: #{id} is the new activity in the outbox")
          {:ok, false, id}
        else
          case ActorFacade.db_exists?(context, id) do
            {:ok, false} ->
              {:ok, false, id}

            {:ok, true} ->
              Logger.debug("seen?: #{id} doesn't match #{new_id} and is an existing activity")
              {:ok, true, id}

            {:error, reason} ->
              {:error, reason}
          end
        end

      nil ->
        Logger.error("Inbox forwarding error, no id")
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
          _ -> {:cont, acc}
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
          case Map.get(cols, iri) do
            %{properties: %{"items" => prop}} ->
              case APUtils.to_id(prop) do
                %URI{} = id -> {:cont, [id | acc]}
                _ -> {:halt, {:error, Utils.err_id_required(activity: activity)}}
              end

            _ ->
              case Map.get(ocols, iri) do
                %{properties: %{"orderedItems" => prop}} ->
                  case APUtils.to_id(prop) do
                    %URI{} = id -> {:cont, [id | acc]}
                    _ -> {:halt, {:error, Utils.err_id_required(activity: activity)}}
                  end

                _ ->
                  {:cont, acc}
              end
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
    with {:ok, activity_recipients} <- APUtils.get_recipients(activity),
         # 1. When an object is being delivered to the originating actor's
         #    followers, a server MAY reduce the number of receiving actors
         #    delivered to by identifying all followers which share the same
         #    sharedInbox who would otherwise be individual recipients and
         #    instead deliver objects to said sharedInbox.

         # 2. If an object is addressed to the Public special collection, a
         #    server MAY deliver that object to all known sharedInbox endpoints
         #    on the network.
         {_public_recipients, recipients} <-
           Enum.split_with(activity_recipients, &APUtils.public?(&1)),
         # Verify the inbox on the sender.
         {:ok, actor_iri} <-
           ActorFacade.db_actor_for_outbox(context, outbox_iri),
         {:ok, this_actor} <-
           ActorFacade.db_get(context, actor_iri),
         {:actor_inbox, %URI{} = actor_inbox} <-
           {:actor_inbox, APUtils.get_inbox(this_actor)},
         {:inboxes, {:ok, [_ | _] = recipients}} <-
           {:inboxes, inboxes_for_recipients(context, recipients, actor_inbox)},
         # Post-processing
         activity <- APUtils.strip_hidden_recipients(activity) do
      {:ok, context, activity, recipients}
    else
      {:error, reason} ->
        {:error, reason}

      {:actor_inbox, _} ->
        Logger.error("No inbox for sender")
        {:error, "No inbox for sender #{outbox_iri}"}

      {:inboxes, {:ok, []}} ->
        Logger.debug("No non-public inbox recipients")
        {:ok, context, activity, []}
    end
  end

  def inboxes_for_recipients(context, recipients, actor_inbox \\ nil) when is_list(recipients) do
    # First check if the implemented database logic can return any inboxes
    # from our list of actor IRIs.
    {found_actors, found_inboxes} =
      Enum.reduce(recipients, [], fn actor_iri, acc ->
        case ActorFacade.db_inbox_for_actor(context, actor_iri) do
          {:ok, %URI{} = inbox_iri} ->
            [{actor_iri, {inbox_iri, nil}} | acc]

          _ ->
            acc
        end
      end)
      |> Enum.unzip()

    # For every actor we found an inbox for in the db, we should
    # remove it from the list of actors we still need to dereference
    case Enum.filter(recipients, fn actor_iri ->
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
        # found in the db, to make a complete list of target inbox IRIs
        {:ok, dedupe_iris(found_inboxes ++ remote_inboxes, [actor_inbox])}
    end
  end

  def dedupe_iris(recipients, ignored) do
    filtered_and_deduped_recipients =
      recipients
      |> Enum.filter(fn {inbox, _shared} -> !Enum.member?(ignored, inbox) end)
      |> Map.new()
      |> Map.to_list()

    reduce_shared_inboxes(filtered_and_deduped_recipients)
  end

  def reduce_shared_inboxes(recipients) do
    # Find any common shared inboxes (repeated more than once)
    common_shared_inboxes =
      recipients
      |> Enum.map(&elem(&1, 1))
      |> Enum.reduce(%{}, fn
        %URI{} = inbox, acc ->
          key = URI.to_string(inbox)
          count = Map.get(acc, key, 0)
          Map.put(acc, key, count + 1)

        _, acc ->
          acc
      end)
      |> Map.to_list()
      |> Enum.filter(fn {_inbox_uri, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))

    # Replace inbox with common shared inbox, then dedupe one more time!
    recipients
    |> Enum.map(fn
      {inbox, %URI{} = shared_inbox} ->
        if Enum.member?(common_shared_inboxes, URI.to_string(shared_inbox)) do
          Logger.error("Using shared inbox #{shared_inbox} for #{inbox}")
          shared_inbox
        else
          inbox
        end

      {inbox, _} ->
        inbox
    end)
    |> MapSet.new()
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
      {:ok, actors}
    else
      # TODO Determine if more logic is needed here for inaccessible
      # collections owned by peer servers
      {actors, more} =
        Enum.reduce(actor_ids, {actors, []}, fn iri, {actor_acc, coll_acc} = acc ->
          case dereference_for_resolving_inboxes(context, transport, iri) do
            {:ok, actor, []} when is_struct(actor) ->
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
        resolve_actors(context, transport, more, depth + 1, max_depth, actors)
      end
    end
  end

  @doc """
  Dereferences an IRI solely for finding an actor's inbox IRI to deliver to.

  The returned actor could be nil, if it wasn't an actor (ex: a Collection or
  OrderedCollection).
  """
  def dereference_for_resolving_inboxes(context, transport, %URI{} = actor_iri) do
    with {:ok, m} when is_map(m) <- ActorFacade.db_dereference(context, transport, actor_iri),
         {:ok, %{properties: properties} = actor_or_collection} <-
           Fedi.Streams.JSONResolver.resolve_with_as_context(m) do
      # Attempt to see if the 'actor' is really some sort of type that has
      # an 'items' or 'orderedItems' property.
      if Map.has_key?(m, "inbox") do
        # A real actor
        {:ok, actor_or_collection, []}
      else
        # Should be a (possibly empty) collection.
        # In production, you would want to see if this is a collection
        # or a page, and traverse pages from "first", "next", etc.
        ["items", "orderedItems"]
        |> Enum.reduce_while([], fn prop_name, acc ->
          case Map.get(properties, prop_name) do
            prop when is_struct(prop) ->
              case APUtils.get_ids(prop) do
                {:ok, ids} ->
                  {:cont, acc ++ ids}

                _ ->
                  Logger.error("deref #{actor_iri} has #{prop_name} with no id")
                  {:halt, {:error, "Actor #{actor_iri} has #{prop_name} with no id"}}
              end

            _ ->
              {:cont, acc}
          end
        end)
        |> case do
          {:error, reason} ->
            {:error, reason}

          more_ids ->
            # Can be an empty list
            {:ok, nil, more_ids}
        end
      end
    else
      {:ok, _not_a_map} ->
        Logger.error("deref #{actor_iri} ERROR Not a map")
        {:error, "Not a map"}

      {:error, reason} ->
        Logger.error("deref #{actor_iri} ERROR #{reason}")
        {:error, reason}
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
      {:ok, id}
    else
      {:error, reason} ->
        {:error, reason}

      # If the inbox already contains the URL, early exit.
      {:exists?, {:ok, _}} ->
        {:ok, nil}

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
  def has_inbox_forwarding_values?(
        %{box_iri: _box_iri} = context,
        %URI{} = inbox_iri,
        val,
        max_depth,
        curr_depth
      )
      when is_struct(val) do
    # TODO: inbox_iri and box_iri are always the same. Eliminate one.

    # Stop recurring if we are exceeding the maximum depth and the maximum
    # is a positive number.
    if max_depth > 0 && curr_depth >= max_depth do
      false
    else
      # Determine if we own the 'id' of any values on the properties we care
      # about.
      {types, iris} = APUtils.get_inbox_forwarding_values(val)

      with false <- owns_any_iri?(context, iris),
           false <- owns_any_id?(context, types) do
        # We must dereference the types
        derefed_types = dereference_iris(context, iris)
        # Recurse
        Enum.any?(types ++ derefed_types, fn next_val ->
          has_inbox_forwarding_values?(context, inbox_iri, next_val, max_depth, curr_depth + 1)
        end)
      end
    end
  end

  # For IRIs, simply check if we own them.
  def owns_any_iri?(context, iris) do
    Enum.any?(iris, fn iri ->
      case ActorFacade.db_owns?(context, iri) do
        {:ok, true} ->
          true

        _ ->
          false
      end
    end)
  end

  # For embedded literals, check the id.
  def owns_any_id?(context, types) do
    Enum.any?(types, fn as_value ->
      case Utils.get_json_ld_id(as_value) do
        %URI{} = id ->
          case ActorFacade.db_owns?(context, id) do
            {:ok, true} -> true
            _ -> false
          end

        _ ->
          false
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
           {:ok, as_type} <- Fedi.Streams.JSONResolver.resolve_with_as_context(m) do
        [as_type | acc]
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

  def set_object_attributed_to_and_id(context, %URI{} = actor_iri, object) do
    # FIXME This will happen later in SocialActivityHandler.create
    # but db_new_id requires an actor to build the id.
    # Perhaps take it out of the context instead?
    object =
      if Utils.get_iri(object, "attributedTo") do
        object
      else
        Utils.set_iri(object, "attributedTo", actor_iri)
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
  def wrap_for_federated_protocol(context, box_iri, new_id \\ nil) do
    on_follow =
      case ActorFacade.on_follow(context) do
        {:ok, value} when is_atom(value) -> value
        _ -> :do_nothing
      end

    struct(context,
      box_iri: box_iri,
      on_follow: on_follow,
      new_activity_id: new_id
    )
  end
end
