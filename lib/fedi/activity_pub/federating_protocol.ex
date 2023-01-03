defmodule Fedi.ActivityPub.FederatingProtocol do
  @moduledoc """
  FederatingProtocol contains behaviors an application needs to satisfy for the
  full ActivityPub S2S implementation to be supported by this library.

  It is only required if the client application wants to support the server-to-
  server, or federating, protocol.

  It is passed to the library as a dependency injection from the client
  application.
  """

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
  @callback post_inbox_request_body_hook(
              context :: struct(),
              request :: Plug.Conn.t(),
              activity :: struct()
            ) ::
              {:ok, Plug.Conn.t()} | {:error, term()}

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
  @callback authenticate_post_inbox(context :: struct(), request :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), authenticated :: boolean()}} | {:error, term()}

  @doc """
  Called for types that can be deserialized but
  are not handled by the application's type-specific callbacks.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  default_callback.
  """
  @callback default_callback(context :: struct(), activity :: struct()) ::
              {:ok, activity :: struct()} | {:error, term()}

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
  @callback blocked(context :: struct(), actor_iris :: list) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  MaxInboxForwardingRecursionDepth determines how deep to search within
  an activity to determine if inbox forwarding needs to occur.

  Zero or negative numbers indicate infinite recursion.
  """
  @callback max_inbox_forwarding_recursion_depth(context :: struct()) :: {:ok, integer()}

  @doc """
  MaxDeliveryRecursionDepth determines how deep to search within
  collections owned by peers when they are targeted to receive a
  delivery.

  Zero or negative numbers indicate infinite recursion.
  """
  @callback max_delivery_recursion_depth(context :: struct()) :: {:ok, integer()}

  @doc """
  FilterForwarding allows the implementation to apply business logic
  such as blocks, spam filtering, and so on to a list of potential
  Collections and OrderedCollections of recipients when inbox
  forwarding has been triggered.

  The activity is provided as a reference for more intelligent
  logic to be used, but the implementation must not modify it.
  """
  @callback filter_forwarding(context :: struct(), recipients :: list(), activity :: struct()) ::
              {:ok, recipients :: list()} | {:error, term()}

  @doc """
  GetInbox returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  AuthenticateGetInbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  @callback get_inbox(context :: struct(), request :: Plug.Conn.t()) ::
              {:ok, ordered_collection_page :: term()} | {:error, term()}
end
