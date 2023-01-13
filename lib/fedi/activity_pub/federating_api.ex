defmodule Fedi.ActivityPub.FederatingApi do
  @moduledoc """
  FederatingApi contains behaviors an application needs to satisfy for the
  full ActivityPub S2S implementation to be supported by this library.

  It is only required if the client application wants to support the server-to-
  server, or federating, protocol.

  It is passed to the library as a dependency injection from the client
  application.
  """

  @type context() :: Fedi.ActivityPub.Actor.s2s_context()

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
              context :: context(),
              conn :: Plug.Conn.t(),
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
  @callback authenticate_post_inbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, response :: Plug.Conn.t(), authenticated :: boolean()} | {:error, term()}

  @doc """
  Delegates the authorization of an activity that
  has been sent by POST to an inbox.

  Only called if the Federated Protocol is enabled.

  If an error is returned, it is passed back to the caller of
  PostInbox. In this case, the implementation must not write a
  response to the ResponseWriter as is expected that the client will
  do so when handling the error. The 'authorized' is ignored.

  If no error is returned, but authorization fails, then authorized
  must be false and error nil. It is expected that the implementation
  handles writing to the ResponseWriter in this case.

  Finally, if the authentication and authorization succeeds, then
  authorized must be true and error nil. The request will continue
  to be processed.
  """
  @callback authorize_post_inbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, response :: Plug.Conn.t(), authenticated :: boolean()} | {:error, term()}

  @doc """
  Delegates the side effects of adding to the inbox and
  determining if it is a request that should be blocked.

  Only called if the Federated Protocol is enabled.

  As a side effect, PostInbox sets the federated data in the inbox, but
  not on its own in the database, as InboxForwarding (which is called
  later) must decide whether it has seen this activity before in order
  to determine whether to do the forwarding algorithm.

  If the error is ErrObjectRequired or ErrTargetRequired, then a Bad
  Request status is sent in the response.
  """
  @callback post_inbox(
              context :: context(),
              conn :: Plug.Conn.t(),
              inbox_iri :: URI.t(),
              activity :: struct()
            ) ::
              {:ok, response :: Plug.Conn.t()} | {:error, term()}

  @doc """
  Delegates inbox forwarding logic when a POST request
  is received in the Actor's inbox.

  Only called if the Federated Protocol is enabled.

  The delegate is responsible for determining whether to do the inbox
  forwarding, as well as actually conducting it if it determines it
  needs to.

  As a side effect, InboxForwarding must set the federated data in the
  database, independently of the inbox, however it sees fit in order to
  determine whether it has seen the activity before.

  The provided url is the inbox of the recipient of the Activity. The
  Activity is examined for the information about who to inbox forward
  to.

  If an error is returned, it is returned to the caller of PostInbox.
  """

  @callback inbox_fowarding(context :: context(), inbox_iri :: URI.t(), activity :: struct()) ::
              :ok | {:error, term()}

  @doc """
  sends a federated message. Called only if federation is
  enabled.

  Called if the Federated Protocol is enabled.

  The provided url is the outbox of the sender. The Activity contains
  the information about the intended recipients.

  If an error is returned, it is returned to the caller of PostOutbox.
  """
  @callback deliver(context :: context(), outbox_iri :: URI.t(), activity :: struct()) ::
              :ok | {:error, term()}

  @doc """
  Called for types that can be deserialized but
  are not handled by the application's type-specific callbacks.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  default_callback.
  """
  @callback default_callback(context :: context(), activity :: struct()) ::
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
  @callback blocked(context :: context(), actor_iris :: list) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  MaxInboxForwardingRecursionDepth determines how deep to search within
  an activity to determine if inbox forwarding needs to occur.

  Zero or negative numbers indicate infinite recursion.
  """
  @callback max_inbox_forwarding_recursion_depth(context :: context()) :: {:ok, integer()}

  @doc """
  MaxDeliveryRecursionDepth determines how deep to search within
  collections owned by peers when they are targeted to receive a
  delivery.

  Zero or negative numbers indicate infinite recursion.
  """
  @callback max_delivery_recursion_depth(context :: context()) :: {:ok, integer()}

  @doc """
  FilterForwarding allows the implementation to apply business logic
  such as blocks, spam filtering, and so on to a list of potential
  Collections and OrderedCollections of recipients when inbox
  forwarding has been triggered.

  The activity is provided as a reference for more intelligent
  logic to be used, but the implementation must not modify it.
  """
  @callback filter_forwarding(context :: context(), recipients :: list(), activity :: struct()) ::
              {:ok, recipients :: list()} | {:error, term()}
end
