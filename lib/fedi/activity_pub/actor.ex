defmodule Fedi.ActivityPub.Actor do
  @moduledoc """
  An ActivityPub Actor
  """

  require Logger

  alias Fedi.Streams.JSONResolver
  alias Fedi.Streams.Error
  alias Fedi.Streams.Utils
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

  @doc """
  Builds an `Actor` struct, plugging in modules for the delegates and
  activity handlers.

  * `common` - the Elixir module implementing the
    `CommonApi` behaviour used by both the Social API and Federated Protocol.
  * `database` - the Elixir module implementing the `DatabaseApi` behaviour.
  * `opts` - Keyword list specifying the Elixir modules that implement the
     Social API and Federated Protocols. `opts` uses these keys:
  * `:c2s` (optional) - the Elixir module implementing the `SocialApi`
     behaviour.
  * `:c2s_activity_handler` (optional) - the Elixir module implementing the
    `SocialActivityApi` behaviour for activity handlers.
  * `:s2s` (optional) - the Elixir module implementing the `FederatingApi`
     behaviour.
  * `:s2s_activity_handler` (optional) - the Elixir module implementing the
    `FederatingActivityApi` behaviour for activity handlers.
  """
  def new_custom_actor(common, database, opts \\ []) do
    make_actor(__MODULE__, common, database, opts)
  end

  def make_actor(module, common, database, opts) do
    c2s = Keyword.get(opts, :c2s)
    s2s = Keyword.get(opts, :s2s)
    c2s_activity_handler = Keyword.get(opts, :c2s_activity_handler)
    s2s_activity_handler = Keyword.get(opts, :s2s_activity_handler)
    fallback = Keyword.get(opts, :fallback)

    [c2s, s2s, database, fallback]
    |> Enum.each(fn
      nil ->
        :ok

      mod when is_atom(mod) ->
        case Code.ensure_compiled(mod) do
          {:module, _} -> :ok
          {:error, reason} -> raise "Module #{Utils.alias_module(mod)} is not compiled: #{reason}"
        end

      mod ->
        raise "Module #{mod} is not an atom or nil"
    end)

    struct(module,
      common: common,
      database: database,
      c2s: c2s,
      s2s: s2s,
      c2s_activity_handler: c2s_activity_handler,
      s2s_activity_handler: s2s_activity_handler,
      fallback: fallback,
      social_api_enabled?: !is_nil(c2s),
      federated_protocol_enabled?: !is_nil(s2s),
      current_user: Keyword.get(opts, :current_user),
      app_agent: Fedi.Application.app_agent()
    )
  end

  @doc """
  Implements the generic algorithm for handling a POST request to an
  actor's inbox independent on an application. It relies on a delegate to
  implement application specific functionality.
  """
  def handle_post_inbox(
        %{federated_protocol_enabled?: federated_protocol_enabled?} = context,
        %Plug.Conn{} = conn,
        _params \\ %{}
      ) do
    inbox_iri = APUtils.request_id(conn)
    context = struct(context, box_iri: inbox_iri)

    with {:is_activity_pub_post, true} <-
           {:is_activity_pub_post, APUtils.is_activity_pub_post(conn)},
         {:protocol_enabled, true} <-
           {:protocol_enabled, federated_protocol_enabled?},
         # Check the peer request is authentic.
         {:authenticated, {:ok, context, conn, true}} <-
           {:authenticated, ActorFacade.authenticate_post_inbox(context, conn, top_level: true)},
         # Begin processing the request, but have not yet applied
         # authorization (ex: blocks). Obtain the activity reject unknown
         # activities.
         {:ok, conn, m} <-
           APUtils.decode_json_body(conn),
         {:matched_type, {:ok, as_value}} <-
           {:matched_type, JSONResolver.resolve(m)},
         {:valid_activity, {:ok, activity, _activity_id}} <-
           {:valid_activity, APUtils.validate_activity(as_value)},

         # Allow server implementations to set context data with a hook.
         {:ok, context} <-
           ActorFacade.post_inbox_request_body_hook(context, conn, activity, top_level: true),

         # Check authorization of the activity.
         {:authorized, {:ok, conn, true}} <-
           {:authorized,
            ActorFacade.authorize_post_inbox(context, conn, activity, top_level: true)},

         # Post the activity to the actor's inbox and trigger side effects for
         # that particular Activity type. It is up to the delegate to resolve
         # the given map.
         {:post_inbox, :ok} <-
           {:post_inbox, ActorFacade.post_inbox(context, inbox_iri, activity, top_level: true)},

         # Our side effects are complete, now delegate determining whether to
         # do inbox forwarding, as well as the action to do it.
         :ok <-
           ActorFacade.inbox_forwarding(context, inbox_iri, activity, top_level: true) do
      # Request has been processed. Begin responding to the request.
      # Simply respond with an OK status to the peer.
      {:ok, Plug.Conn.send_resp(conn, :ok, "OK")}
    else
      {:error, reason} ->
        {:error, reason}

      # Do nothing if it is not an ActivityPub POST request.
      {:is_activity_pub_post, _} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_post)}

      # If the Federated Protocol is not enabled, then this endpoint is not
      # enabled.
      {:protocol_enabled, _} ->
        {:ok, APUtils.send_json_resp(conn, :method_not_allowed, actor_state: :protocol_enabled)}

      # Not authenticated
      {:authenticated, {:ok, _, conn, _}} ->
        {:ok, APUtils.send_json_resp(conn, :unauthorized, actor_state: :authenticated)}

      # Respond with bad request -- we do not understand the type.
      {:matched_type, {:error, %Error{code: :unhandled_type}}} ->
        {:ok, APUtils.send_json_resp(conn, :bad_request, actor_state: :matched_type)}

      {:valid_activity, {:error, %Error{code: :missing_id}}} ->
        {:ok, APUtils.send_json_resp(conn, :bad_request, actor_state: :valid_activity)}

      {:authorized, {:ok, conn, _}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authorized)}

      # Special case: We know it is a bad request if the object or
      # target properties needed to be populated, but weren't.
      # Send the rejection to the peer.
      {:post_inbox, {:error, %Error{code: :object_required}}} ->
        {:ok, APUtils.send_json_resp(conn, :bad_request, actor_state: :post_inbox)}

      {:post_inbox, {:error, %Error{code: :target_required}}} ->
        {:ok, APUtils.send_json_resp(conn, :bad_request, actor_state: :post_inbox)}
    end
  end

  @doc """
  Implements the generic algorithm for handling a GET request to an
  actor's inbox independent on an application. It relies on a delegate to
  implement application specific functionality.
  """
  def handle_get_inbox(context, %Plug.Conn{} = conn, params \\ %{}) do
    inbox_iri = APUtils.request_id(conn)
    context = struct(context, box_iri: inbox_iri)

    with {:is_activity_pub_get, true} <-
           {:is_activity_pub_get, APUtils.is_activity_pub_get(conn)},

         # Delegate authenticating and authorizing the request.
         {:authenticated, {:ok, context, conn, true}} <-
           {:authenticated, ActorFacade.authenticate_get_inbox(context, conn, top_level: true)},

         # Everything is good to begin processing the request.
         {:ok, conn, oc} <-
           ActorFacade.get_inbox(context, conn, params, top_level: true),

         # Deduplicate the 'orderedItems' property by id.
         {:ok, oc} <-
           APUtils.dedupe_ordered_items(oc),

         # Request has been processed. Begin responding to the request.
         # Serialize the OrderedCollection.
         {:ok, m} <-
           Fedi.Streams.Serializer.serialize(oc),
         {:ok, json_body} <-
           Jason.encode(m) do
      {:ok,
       conn
       |> APUtils.add_response_headers(json_body)
       |> Plug.Conn.send_resp(:ok, json_body)}
    else
      {:error, reason} ->
        {:error, reason}

      # Do nothing if it is not an ActivityPub GET request.
      {:is_activity_pub_get, _} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_get)}

      # Not authenticated
      {:authenticated, {:ok, _, conn, _}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authenticated)}
    end
  end

  @doc """
  Implements the generic algorithm for handling a POST request to an
  actor's outbox independent on an application. It relies on a delegate to
  implement application specific functionality.
  """
  def handle_post_outbox(
        %{social_api_enabled?: social_api_enabled?} = context,
        %Plug.Conn{} = conn,
        _params \\ %{}
      ) do
    outbox_iri = APUtils.request_id(conn)
    context = struct(context, box_iri: outbox_iri)

    with {:is_activity_pub_post, true} <-
           {:is_activity_pub_post, APUtils.is_activity_pub_post(conn)},
         {:protocol_enabled, true} <-
           {:protocol_enabled, social_api_enabled?},
         # Check the peer request is authentic.
         {:authenticated, {:ok, context, conn, true}} <-
           {:authenticated, ActorFacade.authenticate_post_outbox(context, conn, top_level: true)},
         # Begin processing the request, but have not yet applied
         # authorization (ex: blocks). Obtain the activity reject unknown
         # activities.
         {:ok, conn, m} <-
           APUtils.decode_json_body(conn),
         {:matched_type, {:ok, as_value}} <-
           {:matched_type, JSONResolver.resolve(m)},
         # It's ok to post just an object
         {:valid_activity, {:ok, activity, activity_id}} <-
           {:valid_activity, ensure_activity(context, as_value, outbox_iri)},
         # Allow server implementations to set context data with a hook.
         {:ok, context} <-
           ActorFacade.post_outbox_request_body_hook(context, conn, activity, top_level: true),
         # The HTTP request steps are complete, complete the rest of the outbox
         # and delivery process.
         {:delivered, :ok} <-
           {:delivered, deliver(context, outbox_iri, activity, m)} do
      # Respond to the request with the new Activity's IRI location.
      #
      # Ref: [AP Section 6](https://www.w3.org/TR/activitypub/#client-to-server-interactions)
      # Servers MUST return a 201 Created HTTP code, and unless the activity
      # is transient, MUST include the new id in the Location header.
      location = URI.to_string(activity_id)

      {:ok,
       conn
       |> Plug.Conn.put_resp_header("location", location)
       |> Plug.Conn.send_resp(:created, "")}
    else
      {:error, reason} ->
        Logger.error("handle_post_outbox #{reason}")
        {:error, reason}

      # Do nothing if it is not an ActivityPub POST request.
      {:is_activity_pub_post, _} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_post)}

      # If the Social API is not enabled, then this endpoint is not enabled.
      #
      # Ref: [AP Section 6](https://www.w3.org/TR/activitypub/#client-to-server-interactions)
      # Attempts to submit objects to servers not implementing client to
      # server support SHOULD result in a 405 Method Not Allowed response.
      {:protocol_enabled, _} ->
        {:ok, APUtils.send_json_resp(conn, :method_not_allowed, actor_state: :protocol_enabled)}

      # Not authenticated
      {:authenticated, {:ok, _, conn, _}} ->
        {:ok, APUtils.send_json_resp(conn, :unauthorized, actor_state: :autenticated)}

      # We know it is a bad request if the object or
      # target properties needed to be populated, but weren't.

      # Send the rejection to the client.
      {:matched_type, {:error, %Error{code: :unhandled_type} = error}} ->
        {:ok, APUtils.send_json_resp(conn, error, actor_state: :matched_type)}

      # Send the rejection to the client.
      {:valid_activity, {:error, %Error{code: :missing_id} = error}} ->
        {:ok, APUtils.send_json_resp(conn, error, actor_state: :valid_activity)}

      {:authorized, {:ok, conn, _}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authorized)}

      # Special case: We know it is a bad request if the object or
      # target properties needed to be populated, but weren't.
      # Send the rejection to the peer.
      {:delivered, {:error, %Error{code: :object_required} = error}} ->
        {:ok, APUtils.send_json_resp(conn, error, actor_state: :delivered)}

      {:delivered, {:error, %Error{code: :target_required} = error}} ->
        {:ok, APUtils.send_json_resp(conn, error, actor_state: :delivered)}

      {step, {:error, %Error{} = error}} ->
        Logger.error("failed in step #{step}: #{error}")
        {:ok, APUtils.send_json_resp(conn, error, actor_state: step)}

      {step, {:error, reason}} ->
        Logger.error("failed in step #{step}: #{reason}")
        {:ok, APUtils.send_json_resp(conn, :internal_server_error, actor_state: step)}
    end
  end

  @doc """
  Implements the generic algorithm for handling a Get request to an
  actor's outbox independent on an application. It relies on a delegate to
  implement application specific functionality.
  """
  def handle_get_outbox(context, %Plug.Conn{} = conn, params \\ %{}) do
    outbox_iri = APUtils.request_id(conn)
    context = struct(context, box_iri: outbox_iri)

    with {:is_activity_pub_get, true} <-
           {:is_activity_pub_get, APUtils.is_activity_pub_get(conn)},

         # Delegate authenticating and authorizing the request.
         {:authenticated, {:ok, context, conn, true}} <-
           {:authenticated, ActorFacade.authenticate_get_outbox(context, conn, top_level: true)},

         # Everything is good to begin processing the request.
         {:ok, conn, oc} <-
           ActorFacade.get_outbox(context, conn, params, top_level: true),

         # Request has been processed. Begin responding to the request.
         # Serialize the OrderedCollection.
         {:ok, m} <-
           Fedi.Streams.Serializer.serialize(oc),
         {:ok, json_body} <-
           Jason.encode(m) do
      {:ok,
       conn
       |> APUtils.add_response_headers(json_body)
       |> Plug.Conn.send_resp(:ok, json_body)}
    else
      {:error, reason} ->
        {:error, reason}

      # Do nothing if it is not an ActivityPub GET request.
      {:is_activity_pub_get, _} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_get)}

      # Not authenticated
      {:authenticated, {:ok, _, conn, _}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authenticated)}
    end
  end

  @doc """
  Sends a federated activity.

  `outbox_iri` must be the outbox of the sender. All processing of
  the activity occurs similarly to the C2S flow:
    - If `as_value` is not an Activity, it is wrapped in a Create activity.
    - A new id is generated for the activity.
    - The activity is added to the specified outbox.
    - The activity is prepared and delivered to recipients.

  Note that this function will only behave as expected if the
  implementation has been constructed to support federation. This
  method will guaranteed work for non-custom Actors. For custom actors,
  care should be used to not call this method if only C2S is supported.

  Send is programmatically accessible if the Federated Protocol is enabled.
  """
  def send(
        %{federated_protocol_enabled?: true} = actor,
        %URI{} = outbox_iri,
        as_value
      )
      when is_struct(as_value) do
    deliver(actor, outbox_iri, as_value, nil)
  end

  @doc """
  Delegates all outbox handling steps and optionally will federate the
  activity if the Federated Protocol is enabled.

  * `outbox_iri` - the outbox of the sender.
  * `m` - the map from the previously serialized Activity.

  Note: `m` may be nil.
  """
  def deliver(
        %{federated_protocol_enabled?: federated_protocol_enabled?} = actor,
        %URI{} = outbox_iri,
        as_value,
        m
      )
      when is_struct(as_value) do
    # If the value is not an Activity or type extending from Activity, then
    # we need to wrap it in a Create Activity.
    with {:ok, activity, _activity_id} <-
           ensure_activity(actor, as_value, outbox_iri),
         # Post the activity to the actor's outbox and trigger side effects for
         # that particular Activity type.
         # Since 'm' is nil-able and side effects may need access to literal nil
         # values, such as for Update activities, ensure 'm' is non-nil.
         {:ok, m} <-
           ensure_serialized(m, activity),
         {:ok, deliverable} <-
           ActorFacade.post_outbox(actor, activity, outbox_iri, m, top_level: true) do
      # Request has been processed and all side effects internal to this
      # application server have finished. Begin side effects affecting other
      # servers and/or the client who sent this request.
      # If we are federating and the type is a deliverable one, then deliver
      # the activity to federating peers.
      if federated_protocol_enabled? && deliverable do
        ActorFacade.deliver(actor, outbox_iri, activity, top_level: true)
      else
        :ok
      end
    else
      {:error, reason} -> {:error, reason}
      {:valid_activity, _} -> {:error, "Wrapped activity is invalid"}
    end
  end

  @doc """
  Verifies that the value is an Activity type, and wraps the
  Activity in a Create activity if it isn't.

  Ref: [AP Section 6.2.1](https://www.w3.org/TR/activitypub/#object-without-create)
  The server MUST accept a valid [ActivityStreams] object that isn't a
  subtype of Activity in the POST request to the outbox. The server then
  MUST attach this object as the object of a Create Activity. For
  non-transient objects, the server MUST attach an id to both the
  wrapping Create and its wrapped Object.
  """
  def ensure_activity(actor, as_value, outbox) when is_struct(as_value) do
    activity_result =
      if APUtils.is_or_extends?(as_value, "Activity") do
        {:ok, as_value}
      else
        ActorFacade.wrap_in_create(actor, as_value, outbox, top_level: true)
      end

    with {:ok, activity} <- activity_result,
         # At this point, this should be a safe conversion. If this error is
         # triggered, then there is either a bug in the delegation of
         # WrapInCreate, behavior is not lining up in the generated ExtendedBy
         # code, or something else is incorrect with the type system.
         {:is_activity, true} <- {:is_activity, APUtils.is_or_extends?(activity, "Activity")},
         # Delegate generating new IDs for the activity and all new objects.
         {:ok, activity} <-
           ActorFacade.add_new_ids(actor, activity, top_level: true) do
      APUtils.validate_activity(activity)
    else
      {:error, result} -> {:error, result}
      {:is_activity, _} -> {:error, "Not an activity"}
    end
  end

  defp ensure_serialized(m, _activity) when is_map(m), do: {:ok, m}

  defp ensure_serialized(nil, activity) do
    case Fedi.Streams.Serializer.serialize(activity) do
      {:ok, m} -> {:ok, m}
      {:error, reason} -> {:error, reason}
    end
  end
end
