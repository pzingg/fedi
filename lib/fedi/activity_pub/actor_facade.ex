defmodule Fedi.ActivityPub.ActorFacade do
  @moduledoc """
  Typespecs for "apply" functions.
  """

  require Logger

  alias Fedi.Streams.Utils

  @type on_follow() :: :do_nothing | :automatically_accept | :automatically_reject
  @type c2s_handler_result() ::
          :pass | {:ok, deliverable :: boolean()} | {:error, term()}
  @type s2s_handler_result() :: :pass | :ok | {:error, term()}

  @typedoc """
  Wrapped data passed in the actor's data element for the Social API.
  """
  @type c2s_data() :: %{
          box_iri: URI.t(),
          app_agent: String.t(),
          raw_activity: map(),
          deliverable: boolean()
        }

  @typedoc """
  Context for Social API callbacks.
  """
  @type c2s_context() :: %{
          __struct__: module(),
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          c2s_activity_handler: module() | nil,
          s2s_activity_handler: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          social_api_enabled?: boolean(),
          federated_protocol_enabled?: boolean(),
          data: c2s_data()
        }

  @typedoc """
  Wrapped data passed in the actor's data element for the Federated Protocol.
  """
  @type s2s_data() :: %{
          box_iri: URI.t(),
          app_agent: String.t(),
          on_follow: on_follow()
        }

  @typedoc """
  Context for Federated Protocol callbacks.
  """
  @type s2s_context() :: %{
          __struct__: module(),
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          c2s_activity_handler: module() | nil,
          s2s_activity_handler: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          social_api_enabled?: boolean(),
          federated_protocol_enabled?: boolean(),
          data: s2s_data()
        }

  @typedoc """
  Generic context.
  """
  @type context() :: %{
          __struct__: module(),
          common: module(),
          c2s: module() | nil,
          s2s: module() | nil,
          c2s_activity_handler: module() | nil,
          s2s_activity_handler: module() | nil,
          fallback: module() | nil,
          database: module() | nil,
          social_api_enabled?: boolean(),
          federated_protocol_enabled?: boolean(),
          data: c2s_data() | s2s_data()
        }

  ### delegate and api callbacks

  # In this module we are purposely overspec'ing the function signatures
  @dialyzer :no_contracts

  @spec authenticate_get_inbox(
          context :: context(),
          conn :: Plug.Conn.t(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t(), authenticated :: boolean} | {:error, term()}
  def authenticate_get_inbox(context, conn, opts \\ []) do
    delegate(context, :common, :authenticate_get_inbox, [context, conn], opts)
  end

  @spec get_inbox(
          context :: context(),
          conn :: Plug.Conn.t(),
          params :: map(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t(), ordered_collection :: struct()}
          | {:error, term()}
  def get_inbox(context, conn, params, opts \\ []) do
    delegate(context, :common, :get_inbox, [context, conn, params], opts)
  end

  @spec authenticate_get_outbox(context :: context(), conn :: Plug.Conn.t(), opts :: Keyword.t()) ::
          {:ok, response :: Plug.Conn.t(), authenticated :: boolean} | {:error, term()}
  def authenticate_get_outbox(context, conn, opts \\ []) do
    delegate(context, :common, :authenticate_get_outbox, [context, conn], opts)
  end

  @spec get_outbox(
          context :: context(),
          conn :: Plug.Conn.t(),
          params :: map(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t(), ordered_collection :: struct()}
          | {:error, term()}
  def get_outbox(context, conn, params, opts \\ []) do
    delegate(context, :common, :get_outbox, [context, conn, params], opts)
  end

  @spec authenticate_post_outbox(
          context :: context(),
          conn :: Plug.Conn.t(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t(), authenticated :: boolean} | {:error, term()}
  def authenticate_post_outbox(context, conn, opts \\ []) do
    delegate(context, :c2s, :authenticate_post_outbox, [context, conn], opts)
  end

  @spec post_outbox_request_body_hook(
          context :: context(),
          conn :: Plug.Conn.t(),
          activity :: struct(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t()} | {:error, term()}
  def post_outbox_request_body_hook(context, conn, activity, opts \\ []) do
    delegate(context, :c2s, :post_outbox_request_body_hook, [context, conn, activity], opts)
  end

  @spec post_outbox(
          context :: context(),
          activity :: struct(),
          outbox_iri :: URI.t(),
          raw_json :: map(),
          opts :: Keyword.t()
        ) ::
          {:ok, deliverable :: boolean()} | {:error, term()}
  def post_outbox(context, activity, outbox_iri, raw_json, opts \\ []) do
    delegate(context, :common, :post_outbox, [context, activity, outbox_iri, raw_json], opts)
  end

  @spec add_new_ids(context :: context(), activity :: struct(), opts :: Keyword.t()) ::
          {:ok, activity :: struct()} | {:error, term()}
  def add_new_ids(context, activity, opts \\ []) do
    delegate(context, :c2s, :add_new_ids, [context, activity], opts)
  end

  @spec wrap_in_create(
          context :: context(),
          activity :: struct(),
          outbox_iri :: URI.t(),
          opts :: Keyword.t()
        ) ::
          {:ok, activity :: struct()} | {:error, term()}
  def wrap_in_create(context, activity, outbox_iri, opts \\ []) do
    delegate(context, :c2s, :wrap_in_create, [context, activity, outbox_iri], opts)
  end

  @spec c2s_default_callback(context :: context(), activity :: struct(), opts :: Keyword.t()) ::
          :pass | {:ok, activity :: struct(), deliverable :: boolean()} | {:error, term()}
  def c2s_default_callback(context, activity, opts \\ []) do
    delegate(context, :c2s, :default_callback, [context, activity], opts)
  end

  @spec authenticate_post_inbox(
          context :: context(),
          conn :: Plug.Conn.t(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t(), authenticated :: boolean()} | {:error, term()}
  def authenticate_post_inbox(context, conn, opts \\ []) do
    delegate(context, :s2s, :authenticate_post_inbox, [context, conn], opts)
  end

  @spec authorize_post_inbox(
          context :: context(),
          conn :: Plug.Conn.t(),
          activity :: struct(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t(), authenticated :: boolean()} | {:error, term()}
  def authorize_post_inbox(context, conn, activity, opts \\ []) do
    delegate(context, :s2s, :authorize_post_inbox, [context, conn, activity], opts)
  end

  @spec post_inbox_request_body_hook(
          context :: context(),
          conn :: Plug.Conn.t(),
          activity :: struct(),
          opts :: Keyword.t()
        ) ::
          {:ok, response :: Plug.Conn.t()} | {:error, term()}
  def post_inbox_request_body_hook(context, conn, activity, opts \\ []) do
    delegate(context, :s2s, :post_inbox_request_body_hook, [context, conn, activity], opts)
  end

  @spec post_inbox(
          context :: context(),
          inbox_iri :: URI.t(),
          activity :: struct(),
          opts :: Keyword.t()
        ) ::
          :ok | {:error, term()}
  def post_inbox(context, inbox_iri, activity, opts \\ []) do
    delegate(context, :s2s, :post_inbox, [context, inbox_iri, activity], opts)
  end

  @spec inbox_forwarding(
          context :: context(),
          inbox_iri :: URI.t(),
          activity :: struct(),
          opts :: Keyword.t()
        ) ::
          :ok | {:error, term()}
  def inbox_forwarding(context, inbox_iri, activity, opts \\ []) do
    delegate(context, :s2s, :inbox_forwarding, [context, inbox_iri, activity], opts)
  end

  @spec deliver(
          context :: context(),
          outbox_iri :: URI.t(),
          activity :: struct(),
          opts :: Keyword.t()
        ) ::
          :ok | {:error, term()}
  def deliver(context, outbox_iri, activity, opts \\ []) do
    delegate(context, :s2s, :deliver, [context, outbox_iri, activity], opts)
  end

  @spec s2s_default_callback(context :: context(), activity :: struct(), opts :: Keyword.t()) ::
          :pass | {:ok, activity :: struct()} | {:error, term()}
  def s2s_default_callback(context, activity, opts \\ []) do
    delegate(context, :s2s, :default_callback, [context, activity], opts)
  end

  @spec blocked(context :: context(), actor_iris :: list(), opts :: Keyword.t()) ::
          {:ok, boolean()} | {:error, term()}
  def blocked(context, actor_iris, opts \\ []) do
    delegate(context, :s2s, :blocked, [context, actor_iris], opts)
  end

  @spec max_inbox_forwarding_recursion_depth(context :: context(), opts :: Keyword.t()) ::
          {:ok, integer()}
  def max_inbox_forwarding_recursion_depth(context, opts \\ []) do
    delegate(context, :s2s, :max_inbox_forwarding_recursion_depth, [context], opts)
  end

  @spec max_delivery_recursion_depth(context :: context(), opts :: Keyword.t()) ::
          {:ok, integer()}
  def max_delivery_recursion_depth(context, opts \\ []) do
    delegate(context, :s2s, :max_delivery_recursion_depth, [context], opts)
  end

  @spec filter_forwarding(
          context :: context(),
          recipients :: list(),
          activity :: struct(),
          opts :: Keyword.t()
        ) ::
          {:ok, recipients :: list()} | {:error, term()}
  def filter_forwarding(context, recipients, activity, opts \\ []) do
    delegate(context, :s2s, :filter_forwarding, [context, recipients, activity], opts)
  end

  @spec on_follow(context :: context(), opts :: Keyword.t()) ::
          {:ok, on_follow()} | {:error, term()}
  def on_follow(context, opts \\ []) do
    delegate(context, :s2s, :on_follow, [context], opts)
  end

  # c2s activity handlers

  @spec handle_c2s_activity(context :: context(), activity :: struct(), opts :: Keyword.t()) ::
          c2s_handler_result()
  def handle_c2s_activity(context, activity, opts \\ []) do
    handle_activity(:c2s, context, activity, opts)
  end

  # s2s activity handlers

  @spec handle_s2s_activity(context :: context(), activity :: struct(), opts :: Keyword.t()) ::
          s2s_handler_result()
  def handle_s2s_activity(context, activity, opts \\ []) do
    handle_activity(:s2s, context, activity, opts)
  end

  ### database

  @spec db_collection_contains?(context :: context, inbox :: struct(), coll_id :: URI.t()) ::
          {:ok, boolean()} | {:error, term()}
  def db_collection_contains?(context, inbox, coll_id) do
    apply(context.database, :collection_contains?, [inbox, coll_id])
  end

  @spec db_get_collection(context :: context, coll_id :: URI.t(), opts :: Keyword.t()) ::
          {:ok, ordered_collection_page :: struct()} | {:error, term()}
  def db_get_collection(context, coll_id, opts) do
    apply(context.database, :get_collection, [coll_id, opts])
  end

  @spec db_update_collection(context :: context, coll_id :: URI.t(), updates :: map()) ::
          {:ok, ordered_collection_page :: struct()} | {:error, term()}
  def db_update_collection(context, coll_id, updates) do
    apply(context.database, :update_collection, [coll_id, updates])
  end

  @spec db_owns?(context :: context, id :: URI.t()) ::
          {:ok, boolean()} | {:error, term()}
  def db_owns?(context, id) do
    apply(context.database, :owns?, [id])
  end

  @spec db_actor_for_collection(context :: context, coll_id :: URI.t()) ::
          {:ok, actor_iri :: URI.t()} | {:error, term()}
  def db_actor_for_collection(context, coll_id) do
    apply(context.database, :actor_for_collection, [coll_id])
  end

  @spec db_actor_for_outbox(context :: context, outbox_iri :: URI.t()) ::
          {:ok, actor_iri :: URI.t()} | {:error, term()}
  def db_actor_for_outbox(context, outbox_iri) do
    apply(context.database, :actor_for_outbox, [outbox_iri])
  end

  @spec db_actor_for_inbox(context :: context, inbox_iri :: URI.t()) ::
          {:ok, actor_iri :: URI.t()} | {:error, term()}
  def db_actor_for_inbox(context, inbox_iri) do
    apply(context.database, :actor_for_inbox, [inbox_iri])
  end

  @spec db_outbox_for_inbox(context :: context, inbox_iri :: URI.t()) ::
          {:ok, outbox_iri :: URI.t()} | {:error, term()}
  def db_outbox_for_inbox(context, inbox_iri) do
    apply(context.database, :outbox_for_inbox, [inbox_iri])
  end

  @spec db_inbox_for_actor(context :: context, actor_iri :: URI.t()) ::
          {:ok, inbox_iri :: URI.t()} | {:error, term()}
  def db_inbox_for_actor(context, actor_iri) do
    apply(context.database, :inbox_for_actor, [actor_iri])
  end

  @spec db_exists?(context :: context, id :: URI.t()) ::
          {:ok, boolean()} | {:error, term()}
  def db_exists?(context, id) do
    apply(context.database, :exists?, [id])
  end

  @spec db_get(context :: context(), id :: URI.t()) ::
          {:ok, struct()} | {:error, term()}
  def db_get(context, id) do
    apply(context.database, :get, [id])
  end

  @spec db_create(context :: context(), as_type :: struct()) ::
          {:ok, as_type :: struct(), json :: map() | nil} | {:error, term()}
  def db_create(context, as_type) do
    apply(context.database, :create, [as_type])
  end

  @spec db_update(context :: context(), as_type :: struct()) ::
          {:ok, updated :: struct()} | {:error, term()}
  def db_update(context, as_type) do
    apply(context.database, :update, [as_type])
  end

  @spec db_delete(context :: context(), id :: URI.t()) ::
          :ok | {:error, term()}
  def db_delete(context, id) do
    apply(context.database, :delete, [id])
  end

  @spec db_new_id(context :: context(), object :: struct()) ::
          {:ok, id :: URI.t()} | {:error, term()}
  def db_new_id(context, object) do
    apply(context.database, :new_id, [object])
  end

  @spec db_new_transport(context :: context(), box_iri :: URI.t(), app_agent :: String.t()) ::
          {:ok, term()} | {:error, term()}
  def db_new_transport(context, box_iri, app_agent) do
    apply(context.database, :new_transport, [box_iri, app_agent])
  end

  @spec db_dereference(context :: context(), transport :: term(), iri :: URI.t()) ::
          {:ok, map()} | {:error, term()}
  def db_dereference(context, transport, iri) do
    apply(context.database, :dereference, [transport, iri])
  end

  @spec db_dereference(
          context :: context(),
          box_iri :: URI.t(),
          app_agent :: String.t(),
          iri :: URI.t()
        ) ::
          {:ok, map()} | {:error, term()}
  def db_dereference(context, box_iri, app_agent, iri) do
    apply(context.database, :dereference, [box_iri, app_agent, iri])
  end

  @spec db_deliver(
          context :: context(),
          transport :: term(),
          json_body :: String.t(),
          iri :: URI.t()
        ) ::
          :ok | {:error, term()}
  def db_deliver(context, transport, json_body, iri) do
    apply(context.database, :deliver, [transport, json_body, iri])
  end

  @spec db_deliver(
          context :: context(),
          box_iri :: URI.t(),
          app_agent :: String.t(),
          json_body :: String.t(),
          iri :: URI.t()
        ) ::
          :ok | {:error, term()}
  def db_deliver(context, box_iri, app_agent, json_body, iri) do
    apply(context.database, :deliver, [box_iri, app_agent, json_body, iri])
  end

  @spec db_batch_deliver(
          context :: context(),
          transport :: term(),
          json_body :: String.t(),
          recipients :: list()
        ) ::
          :ok | {:error, term()}
  def db_batch_deliver(context, transport, json_body, recipients) do
    apply(context.database, :batch_deliver, [transport, json_body, recipients])
  end

  @spec db_batch_deliver(
          context :: context(),
          box_iri :: URI.t(),
          app_agent :: String.t(),
          json_body :: String.t(),
          recipients :: list()
        ) ::
          :ok | {:error, term()}
  def db_batch_deliver(context, box_iri, app_agent, json_body, recipients) do
    apply(context.database, :batch_deliver, [box_iri, app_agent, json_body, recipients])
  end

  # Other public functions

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

  def protocol_supported?(%Plug.Conn{} = conn, which) do
    with {:ok, actor} <- get_actor(conn) do
      protocol_supported?(actor, which)
    else
      _ -> false
    end
  end

  def protocol_supported?(
        %{
          c2s: _,
          s2s: _
        } = actor,
        which
      ) do
    Enum.member?([:c2s, :s2s], which) && !is_nil(Map.get(actor, which))
  end

  ### Implementation

  defp delegate(actor_or_conn, which, func, args, opts)

  defp delegate(%Plug.Conn{} = conn, which, func, args, opts) when is_list(args) do
    with {:ok, actor} <- get_actor(conn) do
      delegate(actor, which, func, args, opts)
    end
  end

  defp delegate(
         %{
           __struct__: context_module,
           fallback: fallback_module,
           common: _,
           c2s: _,
           s2s: _,
           database: _
         } = context,
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
        Logger.debug(
          "Trying top_level #{Utils.alias_module(context_module)} for #{func}/#{arity}"
        )

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
        Logger.debug("Using #{which} #{Utils.alias_module(protocol_module)} for #{func}/#{arity}")
        apply(protocol_module, func, args)

      verify_module(fallback_module) == :ok &&
          function_exported?(fallback_module, func, arity) ->
        Logger.debug(
          "Falling back to #{Utils.alias_module(fallback_module)} for #{func}/#{arity}"
        )

        apply(fallback_module, func, args)

      true ->
        if is_nil(fallback_module) do
          {:error,
           "Function #{func}/#{arity} not found in #{Utils.alias_module(protocol_module)}"}
        else
          {:error,
           "Function #{func}/#{arity} not found in either #{Utils.alias_module(protocol_module)} or #{Utils.alias_module(fallback_module)}"}
        end
    end
  end

  defp handle_activity(which, context, activity, opts)
       when is_atom(which) and is_struct(context) and is_struct(activity) do
    {callback_fn, _namespace} =
      Fedi.Streams.BaseType.get_type_name(activity, atom: true, with_namespace: true)

    top_level = Keyword.get(opts, :top_level, false)

    with {:module, callback_module} when not is_nil(callback_module) <-
           {:module, get_activity_handler_module(context, which, top_level)},
         {:module_exists, :ok} <- {:module_exists, verify_module(callback_module)} do
      cond do
        function_exported?(callback_module, callback_fn, 2) ->
          apply(callback_module, callback_fn, [context, activity])
          |> activity_handler_result(which, context, activity)

        function_exported?(callback_module, :default_callback, 2) ->
          Logger.debug(
            "#{which} Activity handler #{callback_fn} defaulting to #{Utils.alias_module(callback_module)}.default_callback"
          )

          apply(callback_module, :default_callback, [context, activity])
          |> activity_handler_result(which, context, activity)

        true ->
          Logger.error("#{which} Activity handler: no #{callback_fn} or default_callback")
          {:ok, activity, context.data}
      end
    else
      {:module, _} ->
        Logger.error("#{which} Activity handler not set")
        {:error, "#{which} Activity handler not set"}

      {:module_exists, _} ->
        Logger.error("#{which} Activity handler does not exist")
        {:error, "#{which} Activity handler does not exist"}
    end
  end

  defp activity_handler_result(:pass, :c2s, %{data: %{deliverable: deliverable}}, _activity) do
    {:ok, deliverable}
  end

  defp activity_handler_result(:pass, :c2s, _context, _activity) do
    {:ok, true}
  end

  defp activity_handler_result(:pass, :s2s, _context, activity) do
    {:ok, activity}
  end

  defp activity_handler_result(result, _, _, _), do: result

  defp get_activity_handler_module(context, which, true) do
    case which do
      :c2s -> Map.get(context, :c2s_activity_handler)
      :s2s -> Map.get(context, :s2s_activity_handler)
    end
  end

  defp get_activity_handler_module(context, which, _) do
    case which do
      :c2s -> Map.get(context, :c2s)
      :s2s -> Map.get(context, :s2s)
    end
  end

  defp verify_module(nil), do: {:error, "No delegate module"}

  defp verify_module(module) when is_atom(module) do
    with {:module, _} <- Code.ensure_compiled(module) do
      :ok
    else
      {:error, reason} ->
        {:error, "Module #{Utils.alias_module(module)} has not been compiled: #{reason}"}
    end
  end
end
