defmodule Fedi.ActivityPub.SocialApi do
  @moduledoc """
  Contains behaviors an application needs to satisfy for the
  full ActivityPub C2S implementation to be supported by this library.

  It is only required if the client application wants to support the client-to-
  server protocol, or "Social API".
  """

  @type context() :: Fedi.ActivityPub.Actor.c2s_context()

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
  `post_outbox`. In this case, the implementation must not
  send a response to the connection as is expected that the caller
  to `post_outbox` will do so when handling the error.
  """
  @callback post_outbox_request_body_hook(
              context :: context(),
              conn :: Plug.Conn.t(),
              data :: term()
            ) ::
              {:ok, response :: Plug.Conn.t()} | {:error, term()}

  @doc """
  AuthenticatePostOutbox delegates the authentication of a POST to an
  outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  post_outbox. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles sending a response to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  @callback authenticate_post_outbox(context :: context(), conn :: Plug.Conn.t()) ::
              {:ok, response :: Plug.Conn.t(), authenticated :: boolean} | {:error, term()}

  @doc """
  Sets new URL ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of PostOutbox.
  """

  @callback add_new_ids(context :: context(), activity :: struct()) ::
              {:ok, activity :: struct()} | {:error, term()}

  @doc """
  Wraps the provided object in a Create ActivityStreams
  activity. `outbox_iri` is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  @callback wrap_in_create(context :: context(), activity :: struct(), outbox_iri :: URI.t()) ::
              {:ok, activity :: struct()} | {:error, term()}

  @doc """
  Called for types that can be deserialized but
  are not handled by the application's type-specific callbacks.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  default_callback.
  """
  @callback default_callback(context :: context(), activity :: struct()) ::
              {:ok, activity :: struct(), deliverable :: boolean()} | {:error, term()}
end
