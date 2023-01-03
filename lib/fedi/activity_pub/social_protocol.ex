defmodule Fedi.ActivityPub.SocialProtocol do
  @moduledoc """
  SocialProtocol contains behaviors an application needs to satisfy for the
  full ActivityPub C2S implementation to be supported by this library.

  It is only required if the client application wants to support the client-to-
  server, or social, protocol.

  It is passed to the library as a dependency injection from the client
  application.

  Note that certain types of callbacks will be 'wrapped' with default
  behaviors supported natively by the library. Other callbacks
  compatible with streams.TypeResolver can be specified by 'other'.

  For example, setting the 'Create' field in the SocialWrappedCallbacks
  lets an application dependency inject additional behaviors they want
  to take place, including the default behavior supplied by this
  library. This is guaranteed to be compliant with the ActivityPub
  Social protocol.

  To override the default behavior, instead supply the function in
  'other', which does not guarantee the application will be compliant
  with the ActivityPub Social API.

  Applications are not expected to handle every single ActivityStreams
  type and extension. The unhandled ones are passed to DefaultCallback.
  """

  @doc """
  Hook callback after parsing the request body for a client request
  to the Actor's outbox.

  Can be used to set contextual information based on the
  ActivityStreams object received.

  Only called if the Social API is enabled.

  Warning: Neither authentication nor authorization has taken place at
  this time. Doing anything beyond setting contextual information is
  strongly discouraged.

  If an error is returned, it is passed back to the caller of
  post_outbox. In this case, the implementation must not
  write a response to the connection as is expected that the caller
  to post_outbox will do so when handling the error.
  """
  @callback post_outbox_request_body_hook(
              context :: struct(),
              request :: Plug.Conn.t(),
              data :: term()
            ) ::
              {:ok, response :: Plug.Conn.t()} | {:error, term()}

  @doc """
  AuthenticatePostOutbox delegates the authentication of a POST to an
  outbox.

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
  @callback authenticate_post_outbox(context :: struct(), request :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), authenticated :: boolean}} | {:error, term()}

  @doc """
  Called for types that can be deserialized but
  are not handled by the application's type-specific callbacks.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  default_callback.
  """
  @callback default_callback(context :: struct(), activity :: struct()) ::
              {:ok, {activity :: struct(), undeliverable :: boolean()}} | {:error, term()}
end
