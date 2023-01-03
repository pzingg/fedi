defmodule Fedi.ActivityPub.Actor do
  @moduledoc """
  An ActivityPub Actor
  """

  require Logger

  alias Fedi.Streams.JSONResolver
  alias Fedi.ActivityPub.Utils

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

  def new_custom_actor(common, opts \\ []) do
    make_actor(__MODULE__, common, opts)
  end

  def make_actor(module, common, opts) do
    c2s = Keyword.get(opts, :c2s)
    s2s = Keyword.get(opts, :s2s)
    c2s_resolver = Keyword.get(opts, :c2s_resolver)
    s2s_resolver = Keyword.get(opts, :s2s_resolver)
    database = Keyword.get(opts, :database)
    fallback = Keyword.get(opts, :fallback)

    [c2s, s2s, database, fallback]
    |> Enum.each(fn
      nil ->
        :ok

      mod when is_atom(mod) ->
        case Code.ensure_compiled(mod) do
          {:module, _} -> :ok
          {:error, reason} -> raise "Module #{alias_module(mod)} is not compiled: #{reason}"
        end

      mod ->
        raise "Module #{mod} is not an atom or nil"
    end)

    struct(module,
      common: common,
      database: database,
      c2s: c2s,
      s2s: s2s,
      c2s_resolver: c2s_resolver,
      s2s_resolver: s2s_resolver,
      fallback: fallback,
      enable_social_protocol: !is_nil(c2s),
      enable_federated_protocol: !is_nil(s2s),
      data: Keyword.get(opts, :data)
    )
  end

  def get_actor(%Plug.Conn{} = conn) do
    case Map.get(conn.private, :actor) do
      %{__struct__: _, common: _, database: _} = actor -> {:ok, actor}
      _ -> {:error, "No actor in connection"}
    end
  end

  def get_actor!(%Plug.Conn{} = conn) do
    with {:ok, actor} <- get_actor(conn) do
      actor
    else
      _ -> raise "No actor in connection"
    end
  end

  def valid_which?(which) do
    Enum.member?([:c2s, :s2s, :common, :database], which)
  end

  def protocol_supported?(%Plug.Conn{} = conn, which) do
    with {:ok, actor} <- get_actor(conn) do
      protocol_supported?(actor, which)
    else
      _ -> false
    end
  end

  def protocol_supported?(
        %{
          common: _,
          c2s: _,
          s2s: _,
          database: _,
          fallback: _
        } = actor,
        which
      ) do
    valid_which?(which) && !is_nil(Map.get(actor, which))
  end

  defp main_delegate(actor_or_conn, which, func, args) do
    delegate(actor_or_conn, which, func, args, top_level: true)
  end

  def delegate(actor_or_conn, which, func, args, opts \\ [])

  def delegate(%Plug.Conn{} = conn, which, func, args, opts) when is_list(args) do
    with {:ok, actor} <- get_actor(conn) do
      delegate(actor, which, func, args, opts)
    end
  end

  def delegate(
        %{
          common: _,
          c2s: _,
          s2s: _,
          database: _,
          fallback: _
        } = actor,
        which,
        func,
        args,
        opts
      )
      when is_struct(actor) and is_list(args) do
    with {:which, true} <- {:which, valid_which?(which)} do
      apply_if_exported(actor, which, func, [actor | args], opts)
    else
      {:which, _} -> {:error, "Invalid protocol #{which}"}
    end
  end

  def resolver_callback(context, which, activity, opts \\ [])
      when is_struct(context) and is_atom(which) and is_struct(activity) do
    with top_level <-
           Keyword.get(opts, :top_level, false),
         {:module, callback_module} when not is_nil(callback_module) <-
           {:module, get_resolver_module(context, which, top_level)},
         {callback_fn, _namespace} <-
           Fedi.Streams.BaseType.get_type_name(activity, atom: true, with_namespace: true),
         {:module_exists, :ok} <- {:module_exists, verify_module(callback_module)} do
      cond do
        function_exported?(callback_module, callback_fn, 2) ->
          apply(callback_module, callback_fn, [context, activity])

        function_exported?(callback_module, :default_callback, 2) ->
          Logger.debug("Defaulting to #{alias_module(callback_module)}.default_callback")
          apply(callback_module, :default_callback, [context, activity])

        true ->
          Logger.error("No #{callback_fn} or default_callback")
          {:ok, {activity, context.data}}
      end
    else
      :pass ->
        {:ok, {activity, context.data}}

      {:module, _} ->
        Logger.error("No resolver at #{which}")
        {:error, "Invalid protocol #{which}"}

      {:module_exists, _} ->
        Logger.error("Callback module for #{which} does not exist")
        {:error, "Callback module for #{which} does not exist"}
    end
  end

  defp get_resolver_module(context, which, true) do
    case which do
      :c2s -> Map.get(context, :c2s_resolver)
      :s2s -> Map.get(context, :s2s_resolver)
      _ -> nil
    end
  end

  defp get_resolver_module(context, which, _) do
    case which do
      :c2s -> Map.get(context, :c2s)
      :s2s -> Map.get(context, :s2s)
      _ -> nil
    end
  end

  defp apply_if_exported(
         %{__struct__: context_module, fallback: fallback_module} = context,
         which,
         func,
         args,
         opts
       ) do
    arity = Enum.count(args)
    protocol_module = Map.get(context, which)

    {handled, result} =
      if Keyword.get(opts, :top_level, false) && function_exported?(context_module, func, arity) do
        # Called from top-level - check the custom context module
        Logger.debug("Trying top_level #{alias_module(context_module)} for #{func}/#{arity}")

        case apply(context_module, func, args) do
          :pass -> {false, :pass}
          result -> {true, result}
        end
      else
        {false, :pass}
      end

    cond do
      handled ->
        result

      verify_module(protocol_module) == :ok && function_exported?(protocol_module, func, arity) ->
        Logger.debug("Using #{which} #{alias_module(protocol_module)} for #{func}/#{arity}")
        apply(protocol_module, func, args)

      verify_module(fallback_module) == :ok &&
          function_exported?(fallback_module, func, arity) ->
        Logger.debug("Falling back to #{alias_module(fallback_module)} for #{func}/#{arity}")
        apply(fallback_module, func, args)

      true ->
        if is_nil(fallback_module) do
          {:error, "Function #{func}/#{arity} not found in #{alias_module(protocol_module)}"}
        else
          {:error,
           "Function #{func}/#{arity} not found in either #{alias_module(protocol_module)} or #{alias_module(fallback_module)}"}
        end
    end
  end

  defp verify_module(nil), do: {:error, "No delegate module"}

  defp verify_module(module) when is_atom(module) do
    with {:module, _} <- Code.ensure_compiled(module) do
      :ok
    else
      {:error, reason} ->
        {:error, "Module #{alias_module(module)} has not been compiled: #{reason}"}
    end
  end

  defp alias_module(module) when is_atom(module) do
    Module.split(module) |> List.last()
  end

  @doc """
  Implements the generic algorithm for handling a POST request to an
  actor's inbox independent on an application. It relies on a delegate to
  implement application specific functionality.

  Specifying the "scheme" allows for retrieving ActivityStreams content with
  identifiers such as HTTP, HTTPS, or other protocol schemes.
  """
  def handle_post_inbox(
        %{enable_federated_protocol: enable_federated_protocol} = context,
        %Plug.Conn{} = conn,
        scheme \\ "https"
      ) do
    with {:is_activity_pub_post, true} <-
           {:is_activity_pub_post, Utils.is_activity_pub_post(conn)},
         {:protocol_enabled, true} <-
           {:protocol_enabled, enable_federated_protocol},
         # Check the peer request is authentic.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, main_delegate(context, :s2s, :authenticate_post_inbox, [conn])},
         # Begin processing the request, but have not yet applied
         # authorization (ex: blocks). Obtain the activity reject unknown
         # activities.
         {:parsed_json, {:ok, {conn, m}}} <-
           {:parsed_json, Utils.decode_json_body(conn)},
         {:matched_type, {:ok, as_value}} <-
           {:matched_type, JSONResolver.resolve(m)},
         {:valid_activity, {:ok, {activity, _activity_id}}} <-
           {:valid_activity, Utils.valid_activity?(as_value)},

         # Allow server implementations to set context data with a hook.
         {:request_body_hook, {:ok, conn}} <-
           {:request_body_hook,
            main_delegate(context, :s2s, :post_inbox_request_body_hook, [conn, activity])},

         # Check authorization of the activity.
         {:authorized, {:ok, {conn, true}}} <-
           {:authorized, main_delegate(context, :s2s, :authorize_post_inbox, [conn, activity])},
         inbox_id <- Utils.request_id(conn, scheme),

         # Post the activity to the actor's inbox and trigger side effects for
         # that particular Activity type. It is up to the delegate to resolve
         # the given map.
         {:post_inbox, {:ok, {conn, true}}} <-
           {:post_inbox, main_delegate(context, :s2s, :post_inbox, [conn, inbox_id, activity])},

         # Our side effects are complete, now delegate determining whether to
         # do inbox forwarding, as well as the action to do it.
         {:inbox_forwarding, :ok} <-
           {:inbox_forwarding,
            main_delegate(context, :s2s, :inbox_forwarding, [inbox_id, activity])} do
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
  def handle_get_inbox(%{} = context, %Plug.Conn{} = conn) do
    with {:is_activity_pub_get, true} <-
           {:is_activity_pub_get, Utils.is_activity_pub_get(conn)},

         # Delegate authenticating and authorizing the request.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, main_delegate(context, :common, :authenticate_get_inbox, [conn])},

         # Everything is good to begin processing the request.
         {:get_inbox, {:ok, {conn, oc}}} <-
           {:get_inbox, main_delegate(context, :common, :get_inbox, [conn])},

         # Deduplicate the 'orderedItems' property by id.
         {:deduped_items, {:ok, oc}} <-
           {:deduped_items, Utils.dedupe_ordered_items(oc)},

         # Request has been processed. Begin responding to the request.
         # Serialize the OrderedCollection.
         {:serialized, {:ok, m}} <-
           {:serialized, Fedi.Streams.Serializer.serialize(oc)},
         {:encoded, {:ok, json_body}} <-
           {:encoded, Jason.encode(m)} do
      {:ok,
       conn
       |> Utils.add_response_headers(json_body)
       |> Plug.Conn.send_resp(:ok, json_body)}
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
  def handle_post_outbox(
        %{enable_social_protocol: enable_social_protocol} = actor,
        %Plug.Conn{} = conn,
        scheme \\ "https"
      ) do
    with {:is_activity_pub_post, true} <-
           {:is_activity_pub_post, Utils.is_activity_pub_post(conn)},
         {:protocol_enabled, true} <-
           {:protocol_enabled, enable_social_protocol},
         # Check the peer request is authentic.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, main_delegate(actor, :c2s, :authenticate_post_outbox, [conn])},
         # Begin processing the request, but have not yet applied
         # authorization (ex: blocks). Obtain the activity reject unknown
         # activities.
         {:parsed_json, {:ok, {conn, m}}} <-
           {:parsed_json, Utils.decode_json_body(conn)},
         {:matched_type, {:ok, as_value}} <-
           {:matched_type, JSONResolver.resolve(m)},
         {:valid_activity, {:ok, {activity, activity_id}}} <-
           {:valid_activity, Utils.valid_activity?(as_value)},

         # Allow server implementations to set context data with a hook.
         {:request_body_hook, {:ok, conn}} <-
           {:request_body_hook,
            main_delegate(actor, :c2s, :post_outbox_request_body_hook, [conn, activity])},

         # Check authorization of the activity.
         {:authorized, {:ok, {conn, true}}} <-
           {:authorized, main_delegate(actor, :c2s, :authorize_post_inbox, [conn, activity])},
         outbox_id <- Utils.request_id(conn, scheme),

         # The HTTP request steps are complete, complete the rest of the outbox
         # and delivery process.
         {:delivered, :ok} <-
           {:delivered, deliver(actor, outbox_id, activity, m)} do
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
  def handle_get_outbox(%{} = actor, %Plug.Conn{} = conn) do
    with {:is_activity_pub_get, true} <-
           {:is_activity_pub_get, Utils.is_activity_pub_get(conn)},

         # Delegate authenticating and authorizing the request.
         {:authenticated, {:ok, {conn, true}}} <-
           {:authenticated, main_delegate(actor, :common, :authenticate_get_outbox, [conn])},

         # Everything is good to begin processing the request.
         {:get_outbox, {:ok, {conn, oc}}} <-
           {:get_outbox, main_delegate(actor, :common, :get_outbox, [conn])},

         # Request has been processed. Begin responding to the request.
         # Serialize the OrderedCollection.
         {:serialized, {:ok, m}} <-
           {:serialized, Fedi.Streams.Serializer.serialize(oc)},
         {:encoded, {:ok, json_body}} <-
           {:encoded, Jason.encode(m)} do
      {:ok,
       conn
       |> Utils.add_response_headers(json_body)
       |> Plug.Conn.send_resp(:ok, json_body)}
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
  Sends a federated activity.

  The provided url must be the outbox of the sender. All processing of
  the activity occurs similarly to the C2S flow:
    - If t is not an Activity, it is wrapped in a Create activity.
    - A new ID is generated for the activity.
    - The activity is added to the specified outbox.
    - The activity is prepared and delivered to recipients.

  Note that this function will only behave as expected if the
  implementation has been constructed to support federation. This
  method will guaranteed work for non-custom Actors. For custom actors,
  care should be used to not call this method if only C2S is supported.

  Send is programmatically accessible if the federated protocol is enabled.
  """
  def send(
        %{enable_federated_protocol: true} = actor,
        outbox,
        as_value
      ) do
    deliver(actor, outbox, as_value, nil)
  end

  @doc """
  Delegates all outbox handling steps and optionally will federate the
  activity if the federated protocol is enabled.

  Note: `m` may be nil.
  """
  def deliver(
        %{enable_federated_protocol: enable_federated_protocol} = actor,
        %URI{} = outbox,
        as_value,
        m
      )
      when is_struct(as_value) do
    # If the value is not an Activity or type extending from Activity, then
    # we need to wrap it in a Create Activity.
    with {:ensure_activity, {:ok, activity}} <-
           {:ensure_activity, ensure_activity(actor, as_value, outbox)},
         # At this point, this should be a safe conversion. If this error is
         # triggered, then there is either a bug in the delegation of
         # WrapInCreate, behavior is not lining up in the generated ExtendedBy
         # code, or something else is incorrect with the type system.
         {:valid_activity, true} <-
           {:valid_activity, Utils.is_or_extends?(activity, "Activity")},

         # Delegate generating new IDs for the activity and all new objects.
         {:added_new_ids, {:ok, activity}} <-
           {:added_new_ids, main_delegate(actor, :c2s, :add_new_ids, [activity])},

         # Post the activity to the actor's outbox and trigger side effects for
         # that particular Activity type.
         # Since 'm' is nil-able and side effects may need access to literal nil
         # values, such as for Update activities, ensure 'm' is non-nil.
         {:serialized, {:ok, m}} <-
           {:serialized, ensure_serialized(m, activity)},
         {:deliverable, {:ok, deliverable}} <-
           {:deliverable, main_delegate(actor, :c2s, :post_outbox, [activity, outbox, m])} do
      # Request has been processed and all side effects internal to this
      # application server have finished. Begin side effects affecting other
      # servers and/or the client who sent this request.
      # If we are federating and the type is a deliverable one, then deliver
      # the activity to federating peers.
      if enable_federated_protocol && deliverable do
        main_delegate(actor, :s2s, :deliver, [outbox, activity])
      else
        :ok
      end
    else
      {:valid_activity, false} -> {:error, "Wrapped activity is invalid"}
      {_, {:error, reason}} -> {:error, reason}
    end
  end

  defp ensure_activity(actor, as_value, outbox) when is_struct(as_value) do
    if Utils.is_or_extends?(as_value, "Activity") do
      {:ok, as_value}
    else
      # c2s, s2s, or common?
      main_delegate(actor, :c2s, :wrap_in_create, [as_value, outbox])
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
