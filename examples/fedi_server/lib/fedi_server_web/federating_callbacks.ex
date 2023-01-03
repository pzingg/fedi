defmodule FediServerWeb.FederatingCallbacks do
  @moduledoc """
  Implementation of Federating Protocol.
  """

  @behaviour Fedi.ActivityPub.FederatingProtocol

  @doc """
  Hook callback after parsing the request body for a federated request
  to the Actor's inbox.

  Can be used to set contextual information based on the Activity
  received.

  Only called if the Federated Protocol is enabled.

  Warning: Neither authentication nor authorization has taken place at
  this time. Doing anything beyond setting contextual information is
  strongly discouraged.

  If an error is returned, it is passed back to the caller of
  PostInbox. In this case, the DelegateActor implementation must not
  write a response to the ResponseWriter as is expected that the caller
  to PostInbox will do so when handling the error.
  """
  def post_inbox_request_body_hook(context, %Plug.Conn{} = conn, activity) do
    # TODO IMPL
    {:ok, conn}
  end

  @doc """
  AuthenticatePostInbox delegates the authentication of a POST to an
  inbox.

  If an error is returned, it is passed back to the caller of
  PostInbox. In this case, the implementation must not write a
  response to the ResponseWriter as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles writing to the ResponseWriter in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  def authenticate_post_inbox(context, %Plug.Conn{} = conn) do
    # TODO IMPL
    {:ok, {conn, true}}
  end

  @doc """
  Called for types that can be deserialized but
  are not handled by the application's type-specific callbacks.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  default_callback.
  """
  def default_callback(context, activity) when is_struct(context) and is_struct(activity) do
    {:ok, {activity, get_in(context, [:data, :undeliverable])}}
  end

  @doc """
  Blocked should determine whether to permit a set of actors given by
  their ids are able to interact with this particular end user due to
  being blocked or other application-specific logic.

  If an error is returned, it is passed back to the caller of
  PostInbox.

  If no error is returned, but authentication or authorization fails,
  then blocked must be true and error nil. An http.StatusForbidden
  will be written in the wresponse.

  Finally, if the authentication and authorization succeeds, then
  blocked must be false and error nil. The request will continue
  to be processed.
  """
  def blocked(context, actor_iris) when is_list(actor_iris) do
    # TODO IMPL
    {:ok, false}
  end

  @doc """
  MaxInboxForwardingRecursionDepth determines how deep to search within
  an activity to determine if inbox forwarding needs to occur.

  Zero or negative numbers indicate infinite recursion.
  """
  def max_inbox_forwarding_recursion_depth(context) do
    {:ok, 4}
  end

  @doc """
  MaxDeliveryRecursionDepth determines how deep to search within
  collections owned by peers when they are targeted to receive a
  delivery.

  Zero or negative numbers indicate infinite recursion.
  """
  def max_delivery_recursion_depth(context) do
    {:ok, 4}
  end

  @doc """
  FilterForwarding allows the implementation to apply business logic
  such as blocks, spam filtering, and so on to a list of potential
  Collections and OrderedCollections of recipients when inbox
  forwarding has been triggered.

  The activity is provided as a reference for more intelligent
  logic to be used, but the implementation must not modify it.
  """
  def filter_forwarding(context, recipients, activity) when is_list(recipients) do
    # TODO IMPL
    {:ok, recipients}
  end

  @doc """
  GetInbox returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  AuthenticateGetInbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  def get_inbox(context, %Plug.Conn{} = conn) do
    # TODO IMPL
    {:error, "Unimplemented"}
  end
end
