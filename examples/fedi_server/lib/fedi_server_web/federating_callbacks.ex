defmodule FediServerWeb.FederatingCallbacks do
  @moduledoc """
  Implementation of Federating Protocol.
  """

  @behaviour Fedi.ActivityPub.CommonApi
  @behaviour Fedi.ActivityPub.FederatingApi

  require Logger

  alias Fedi.Streams.Utils
  alias FediServerWeb.CommonCallbacks
  alias FediServer.Activities

  @impl true
  defdelegate authenticate_get_inbox(context, conn), to: CommonCallbacks

  @impl true
  defdelegate get_inbox(context, conn, params), to: CommonCallbacks

  @impl true
  defdelegate authenticate_get_outbox(context, conn), to: CommonCallbacks

  @impl true
  defdelegate get_outbox(context, conn, params), to: CommonCallbacks

  @impl true
  defdelegate post_outbox(context, activity, outbox_iri, raw_json), to: CommonCallbacks

  @doc """
  Hook callback after parsing the request body for a federated request
  to the Actor's inbox.

  Only called if the Federated Protocol is enabled.

  Can be used to set contextual information or to prevent further processing
  based on the Activity received.

  Authentication has been approved, but authorization has not been
  checked when this hook is called.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_inbox/3`. In this case, the implementation must not
  send a response to `conn` as is expected that the caller
  to `Actor.handle_post_inbox/3` will do so when handling the error.
  """
  @impl true
  def post_inbox_request_body_hook(context, %Plug.Conn{} = _conn, _activity) do
    # TODO IMPL
    {:ok, context}
  end

  @doc """
  Delegates the authentication of a POST to an inbox.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_inbox/3`. In this case, the implementation must not send a
  response to `conn` as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles sending a response to `conn` in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  @impl true
  def authenticate_post_inbox(context, %Plug.Conn{} = conn) do
    if HTTPSignatures.validate_conn(conn) do
      signer_id = FediServer.HTTPClient.get_signing_actor_id(conn)
      {:ok, struct(context, request_signed_by: signer_id), conn, true}
    else
      {:ok, struct(context, request_signed_by: nil), conn, false}
    end
  end

  @doc """
  Delegates the authorization of an activity that
  has been sent by POST to an inbox.

  Only called if the Federated Protocol is enabled.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_inbox/3`. In this case, the implementation must not send a
  response to `conn` as is expected that the client will
  do so when handling the error. The 'authorized' is ignored.

  If no error is returned, but authorization fails, then authorized
  must be false and error nil. It is expected that the implementation
  handles sending a response to `conn` in this case.

  Finally, if the authorization succeeds, then
  authorized must be true and error nil. The request will continue
  to be processed.
  """
  @impl true
  def authorize_post_inbox(
        %{request_signed_by: %URI{} = signer_id} = _context,
        %Plug.Conn{} = conn,
        activity
      ) do
    with {:activity_actor, %URI{} = actor_iri} <-
           {:activity_actor, Utils.get_actor_or_attributed_to_iri(activity)} do
      if URI.to_string(signer_id) == URI.to_string(actor_iri) do
        {:ok, conn, true}
      else
        Logger.error("Actor #{actor_iri} spoofed by sender #{signer_id}")
        {:ok, conn, false}
      end
    else
      {:activity_actor, _} -> {:error, Utils.err_actor_required(activity: activity)}
    end
  end

  def authorize_post_inbox(_context, %Plug.Conn{} = conn, _activity) do
    Logger.error("No signer to authorize post inbox")
    {:ok, conn, false}
  end

  @doc """
  Delegates the side effects of adding to the inbox and
  determining if it is a request that should be blocked.

  Only called if the Federated Protocol is enabled.

  As a side effect, `Actor.handle_post_inbox/3` sets the federated data in the inbox, but
  not on its own in the database, as InboxForwarding (which is called
  later) must decide whether it has seen this activity before in order
  to determine whether to do the forwarding algorithm.

  If the error is `:object_required` or `:target_required`, then a Bad
  Request status is sent in the response.
  """
  @impl true
  def post_inbox(_context, %URI{} = _inbox_iri, _activity) do
    # TODO IMPL
    :ok
  end

  @doc """
  Delegates inbox forwarding logic when a POST request
  is received in the Actor's inbox.

  Only called if the Federated Protocol is enabled.

  The delegate is responsible for determining whether to do the inbox
  forwarding, as well as actually conducting it if it determines it
  needs to.

  As a side effect, `inbox_forwarding/3` must set the federated data in the
  database, independently of the inbox, however it sees fit in order to
  determine whether it has seen the activity before.

  `inbox_iri` is the inbox of the recipient of the Activity. The
  Activity is examined for the information about who to inbox forward
  to.

  If an error is returned, it is returned to the caller of
  `Actor.handle_post_inbox/3`.
  """
  @impl true
  def inbox_fowarding(_context, %URI{} = _inbox_iri, _activity) do
    # TODO IMPL
    :ok
  end

  @doc """
  Sends a federated message.

  Only called if the Federated Protocol is enabled.

  `outbox_iri` is the outbox of the sender. The Activity contains
  the information about the intended recipients.

  If an error is returned, it is returned to the caller of
  `Actor.handle_post_outbox/3`.
  """
  @impl true
  def deliver(_context, %URI{} = _outbox_iri, _activity) do
    # TODO IMPL
    {:error, "Unimplemented"}
  end

  @doc """
  Blocked should determine whether to permit a set of actors given by
  their ids are able to interact with this particular end user due to
  being blocked or other application-specific logic.

  If an error is returned, it is passed back to the caller of
  `Actor.handle_post_inbox/3`.

  If no error is returned, but authentication or authorization fails,
  then blocked must be true and error nil. An http.StatusForbidden
  will be written in the wresponse.

  Finally, if the authentication and authorization succeeds, then
  blocked must be false and error nil. The request will continue
  to be processed.
  """
  @impl true
  def blocked(%{box_iri: inbox_iri} = _context, actor_iris) when is_list(actor_iris) do
    with {:ok, actor_iri} <- Activities.actor_for_inbox(inbox_iri),
         {:ok, user} <- Activities.ensure_user(actor_iri, true) do
      {:ok, Activities.any_blocked?(user, actor_iris)}
    end
  end

  @doc """
  Determines how deep to search within
  an activity to determine if inbox forwarding needs to occur.

  Zero or negative numbers indicate infinite recursion.
  """
  @impl true
  def max_inbox_forwarding_recursion_depth(_context) do
    {:ok, 4}
  end

  @doc """
  Determines how deep to search within
  collections owned by peers when they are targeted to receive a
  delivery.

  Zero or negative numbers indicate infinite recursion.
  """
  @impl true
  def max_delivery_recursion_depth(_context) do
    {:ok, 4}
  end

  @doc """
  Determines what action to take for this particular callback
  if a Follow activity is handled.
  """
  @impl true
  def on_follow(_context) do
    {:ok, :automatically_accept}
  end

  @doc """
  Allows the implementation to apply business logic
  such as blocks, spam filtering, and so on to a list of potential
  Collections and OrderedCollections of recipients when inbox
  forwarding has been triggered.

  The activity is provided as a reference for more intelligent
  logic to be used, but the implementation must not modify it.
  """
  @impl true
  def filter_forwarding(_context, recipients, _activity) when is_list(recipients) do
    # For this example we don't maintain block lists or other filters.
    {:ok, recipients}
  end

  @doc """
  Called for types that can be deserialized but
  are not handled by the application's type-specific callbacks.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  `default_callback/2`.
  """
  @impl true
  def default_callback(_context, _activity) do
    :pass
  end
end
