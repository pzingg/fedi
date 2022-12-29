defmodule Fedi.ActivityPub.Actor do
  @moduledoc """
  An ActivityPub Actor
  """

  alias Fedi.Streams.JsonResolver
  alias Fedi.ActivityPub.Utils

  @enforce_keys [:delegate]
  defstruct [
    :delegate,
    :enable_social_protocol,
    :enable_federated_protocol
  ]

  def new_custom_actor(delegate, opts \\ []) do
    %__MODULE__{
      delegate: delegate,
      enable_social_protocol: Keyword.get(opts, :enable_social_protocol, false),
      enable_federated_protocol: Keyword.get(opts, :enable_federated_protocol, false)
    }
  end

  @doc """
  post_inbox implements the generic algorithm for handling a POST request to an
  actor's inbox independent on an application. It relies on a delegate to
  implement application specific functionality.

  Specifying the "scheme" allows for retrieving ActivityStreams content with
  identifiers such as HTTP, HTTPS, or other protocol schemes.
  """
  def post_inbox(
        %__MODULE__{delegate: delegate, enable_federated_protocol: enable_federated_protocol},
        %Plug.Conn{} = conn,
        scheme \\ "https"
      ) do
    with {:is_activity_pub_post, true} <-
           {:is_activity_pub_post, Utils.is_activity_pub_post(conn)},
         {:protocol_enabled, true} <-
           {:protocol_enabled, enable_federated_protocol},
         # Check the peer request is authentic.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, apply(delegate, :authenticate_post_inbox, [conn])},
         # Begin processing the request, but have not yet applied
         # authorization (ex: blocks). Obtain the activity reject unknown
         # activities.
         {:parsed_json, {:ok, {conn, m}}} <-
           {:parsed_json, Utils.decode_json_body(conn)},
         {:matched_type, {:ok, as_value}} <-
           {:matched_type, JsonResolver.resolve(m)},
         {:valid_activity, {:ok, {activity, _activity_id}}} <-
           {:valid_activity, Utils.valid_activity(as_value)},

         # Allow server implementations to set context data with a hook.
         {:request_body_hook, {:ok, conn}} <-
           {:request_body_hook, apply(delegate, :post_inbox_request_body_hook, [conn, activity])},

         # Check authorization of the activity.
         {:authorized, {:ok, {conn, true}}} <-
           {:authorized, apply(delegate, :authorize_post_inbox, [conn])},
         inbox_id <- Utils.request_id(conn, scheme),

         # Post the activity to the actor's inbox and trigger side effects for
         # that particular Activity type. It is up to the delegate to resolve
         # the given map.
         {:post_inbox, {:ok, {conn, true}}} <-
           {:post_inbox, apply(delegate, :post_inbox, [conn, inbox_id, activity])},

         # Our side effects are complete, now delegate determining whether to
         # do inbox forwarding, as well as the action to do it.
         {:inbox_forwarding, :ok} <-
           {:inbox_forwarding, apply(delegate, :inbox_forwarding, [inbox_id, activity])} do
      # Request has been processed. Begin responding to the request.
      # Simply respond with an OK status to the peer.
      {:ok, Plug.Conn.send_resp(conn, :ok, "OK")}
    else
      # Do nothing if it is not an ActivityPub POST request.
      {:is_activity_pub_post, false} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_post)}

      # If the Federated Protocol is not enabled, then this endpoint is not
      # enabled.
      {:protocol_enabled, _} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :method_not_allowed,
           "Method not allowed",
           :protocol_enabled
         )}

      # Not authenticated
      {:authenticated, {:ok, {conn, false}}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authenticated)}

      # Respond with bad request -- we do not understand the type.
      {:matched_type, {:error, {:err_unmatched_type, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :matched_type
         )}

      {:valid_activity, {:error, {:err_missing_id, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :valid_activity
         )}

      {:authorized, {:ok, {conn, false}}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authorized)}

      # Special case: We know it is a bad request if the object or
      # target properties needed to be populated, but weren't.
      # Send the rejection to the peer.
      {:post_inbox, {:error, {:err_object_required, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :post_inbox
         )}

      {:post_inbox, {:error, {:err_target_required, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :post_inbox
         )}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Implements the generic algorithm for handling a GET request to an
  actor's inbox independent on an application. It relies on a delegate to
  implement application specific functionality.
  """
  def get_inbox(%__MODULE__{delegate: delegate}, %Plug.Conn{} = conn) do
    with {:is_activity_pub_get, true} <-
           {:is_activity_pub_get, Utils.is_activity_pub_get(conn)},

         # Delegate authenticating and authorizing the request.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, apply(delegate, :authenticate_get_inbox, [conn])},

         # Everything is good to begin processing the request.
         {:get_inbox, {:ok, {conn, oc}}} <-
           {:get_inbox, apply(delegate, :get_inbox, [conn])},

         # Deduplicate the 'orderedItems' property by id.
         {:deduped_items, {:ok, oc}} <-
           {:deduped_items, Utils.dedupe_ordered_items(oc)},

         # Request has been processed. Begin responding to the request.
         # Serialize the OrderedCollection.
         {:serialized, {:ok, m}} <-
           {:serialized, Fedi.Streams.Serializer.serialize(oc)},
         {:encoded, {:ok, json_body}} <-
           {:encoded, Jason.encode(m)} do
      conn
      |> Utils.add_response_headers(json_body)
      |> Plug.Conn.send_resp(:ok, json_body)
    else
      # Do nothing if it is not an ActivityPub GET request.
      {:is_activity_pub_get, false} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_get)}

      # Not authenticated
      {:authenticated, {:ok, {conn, false}}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authenticated)}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Implements the generic algorithm for handling a POST request to an
  actor's outbox independent on an application. It relies on a delegate to
  implement application specific functionality.

  Specifying the "scheme" allows for retrieving ActivityStreams content with
  identifiers such as HTTP, HTTPS, or other protocol schemes.
  """
  def post_outbox(
        %__MODULE__{delegate: delegate, enable_social_protocol: enable_social_protocol},
        %Plug.Conn{} = conn,
        scheme \\ "https"
      ) do
    with {:is_activity_pub_post, true} <-
           {:is_activity_pub_post, Utils.is_activity_pub_post(conn)},
         {:protocol_enabled, true} <-
           {:protocol_enabled, enable_social_protocol},
         # Check the peer request is authentic.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, apply(delegate, :authenticate_post_outbox, [conn])},
         # Begin processing the request, but have not yet applied
         # authorization (ex: blocks). Obtain the activity reject unknown
         # activities.
         {:parsed_json, {:ok, {conn, m}}} <-
           {:parsed_json, Utils.decode_json_body(conn)},
         {:matched_type, {:ok, as_value}} <-
           {:matched_type, JsonResolver.resolve(m)},
         {:valid_activity, {:ok, {activity, activity_id}}} <-
           {:valid_activity, Utils.valid_activity(as_value)},

         # Allow server implementations to set context data with a hook.
         {:request_body_hook, {:ok, conn}} <-
           {:request_body_hook, apply(delegate, :post_outbox_request_body_hook, [conn, activity])},

         # Check authorization of the activity.
         {:authorized, {:ok, {conn, true}}} <-
           {:authorized, apply(delegate, :authorize_post_inbox, [conn])},
         outbox_id <- Utils.request_id(conn, scheme),

         # The HTTP request steps are complete, complete the rest of the outbox
         # and delivery process.
         {:delivered, {:ok, {conn, true}}} <-
           {:delivered, apply(delegate, :deliver, [conn, outbox_id, activity])} do
      # Respond to the request with the new Activity's IRI location.
      location = URI.to_string(activity_id)

      {:ok,
       conn
       |> Plug.Conn.put_resp_header("location", location)
       |> Plug.Conn.send_resp(:created, "")}
    else
      # Do nothing if it is not an ActivityPub POST request.
      {:is_activity_pub_post, false} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_post)}

      # If the Federated Protocol is not enabled, then this endpoint is not
      # enabled.
      {:protocol_enabled, _} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :method_not_allowed,
           "Method not allowed",
           :protocol_enabled
         )}

      # Not authenticated
      {:authenticated, {:ok, {conn, false}}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authenticated)}

      # Respond with bad request -- we do not understand the type.
      {:matched_type, {:error, {:err_unmatched_type, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :matched_type
         )}

      {:valid_activity, {:error, {:err_missing_id, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :valid_activity
         )}

      {:authorized, {:ok, {conn, false}}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authorized)}

      # Special case: We know it is a bad request if the object or
      # target properties needed to be populated, but weren't.
      # Send the rejection to the peer.
      {:delivered, {:error, {:err_object_required, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :delivered
         )}

      {:delivered, {:error, {:err_target_required, _reason}}} ->
        {:ok,
         Utils.send_text_resp(
           conn,
           :bad_request,
           "Bad request",
           :delivered
         )}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Implements the generic algorithm for handling a Get request to an
  actor's outbox independent on an application. It relies on a delegate to
  implement application specific functionality.
  """
  def get_outbox(%__MODULE__{delegate: delegate}, %Plug.Conn{} = conn) do
    with {:is_activity_pub_get, true} <-
           {:is_activity_pub_get, Utils.is_activity_pub_get(conn)},

         # Delegate authenticating and authorizing the request.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, apply(delegate, :authenticate_get_outbox, [conn])},

         # Everything is good to begin processing the request.
         {:get_outbox, {:ok, {conn, oc}}} <-
           {:get_outbox, apply(delegate, :get_outbox, [conn])},

         # Request has been processed. Begin responding to the request.
         # Serialize the OrderedCollection.
         {:serialized, {:ok, m}} <-
           {:serialized, Fedi.Streams.Serializer.serialize(oc)},
         {:encoded, {:ok, json_body}} <-
           {:encoded, Jason.encode(m)} do
      conn
      |> Utils.add_response_headers(json_body)
      |> Plug.Conn.send_resp(:ok, json_body)
    else
      # Do nothing if it is not an ActivityPub GET request.
      {:is_activity_pub_get, false} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :is_activity_pub_get)}

      # Not authenticated
      {:authenticated, {:ok, {conn, false}}} ->
        {:ok, Plug.Conn.put_private(conn, :actor_state, :authenticated)}

      {_, {:error, reason}} ->
        {:error, reason}
    end
  end

  def ensure_activity(delegate, as_value, outbox) do
    if Utils.is_or_extends_activity(as_value) do
      {:ok, as_value}
    else
      apply(delegate, :wrap_in_create, [as_value, outbox])
    end
  end

  def ensure_serialized(m, _activity) when is_map(m), do: {:ok, m}

  def ensure_serialized(nil, activity) do
    case Fedi.Streams.Serializer.serialize(activity) do
      {:ok, m} -> {:ok, m}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delegates all outbox handling steps and optionally will federate the
  activity if the federated protocol is enabled.

  This function is not exported so an Actor that only supports C2S cannot be
  type casted to a FederatingActor. It doesn't exactly fit the Send method
  signature anyways.
  """
  def deliver(
        %__MODULE__{delegate: delegate, enable_federated_protocol: enable_federated_protocol},
        outbox,
        as_value,
        m \\ nil
      ) do
    # If the value is not an Activity or type extending from Activity, then
    # we need to wrap it in a Create Activity.
    with {:ensure_activity, {:ok, activity}} <-
           {:ensure_activity, ensure_activity(delegate, as_value, outbox)},
         # At this point, this should be a safe conversion. If this error is
         # triggered, then there is either a bug in the delegation of
         # WrapInCreate, behavior is not lining up in the generated ExtendedBy
         # code, or something else is incorrect with the type system.
         {:valid_activity, true} <-
           {:valid_activity, Utils.is_or_extends_activity(activity)},

         # Delegate generating new IDs for the activity and all new objects.
         {:added_new_ids, {:ok, activity}} <-
           {:added_new_ids, apply(delegate, :add_new_ids, [activity])},

         # Post the activity to the actor's outbox and trigger side effects for
         # that particular Activity type.
         # Since 'm' is nil-able and side effects may need access to literal nil
         # values, such as for Update activities, ensure 'm' is non-nil.
         {:serialized, {:ok, m}} <-
           {:serialized, ensure_serialized(m, activity)},
         {:deliverable, {:ok, deliverable}} <-
           {:deliverable, apply(delegate, :post_outbox, [activity, outbox, m])} do
      # Request has been processed and all side effects internal to this
      # application server have finished. Begin side effects affecting other
      # servers and/or the client who sent this request.
      # If we are federating and the type is a deliverable one, then deliver
      # the activity to federating peers.
      if enable_federated_protocol && deliverable do
        apply(delegate, :deliver, [outbox, activity])
      else
        :ok
      end
    else
      {:valid_activity, false} -> {:error, "Wrapped activity is invalid"}
      {_, {:error, reason}} -> {:error, reason}
    end
  end

  @doc """
  Send is programmatically accessible if the federated protocol is enabled.
  """
  def send(
        %__MODULE__{enable_federated_protocol: true} = actor,
        outbox,
        as_value
      ) do
    deliver(actor, outbox, as_value, nil)
  end
end
