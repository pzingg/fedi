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

  @optional_callbacks [
    create: 2,
    update: 2,
    delete: 2,
    follow: 2,
    add: 2,
    remove: 2,
    like: 2,
    undo: 2,
    block: 2
  ]

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
  PostOutbox. In this case, the DelegateActor implementation must not
  write a response to the ResponseWriter as is expected that the caller
  to PostOutbox will do so when handling the error.
  """
  @callback post_outbox_request_body_hook(
              actor :: struct(),
              request :: Plug.Conn.t(),
              data :: term()
            ) ::
              {:ok, response :: Plug.Conn.t()} | {:error, term()}

  @doc """
  AuthenticatePostOutbox delegates the authentication of a POST to an
  outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  PostOutbox. In this case, the implementation must not write a
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
  @callback authenticate_post_outbox(actor :: struct(), request :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), authenticated :: boolean}} | {:error, term()}

  @doc """
  DefaultCallback is called for types that go-fed can deserialize but
  are not handled by the application's callbacks.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  DefaultCallback.
  """
  @callback default_callback(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Handles additional side effects for the Create ActivityStreams
  type.

  The wrapping callback copies the actor(s) to the 'attributedTo'
  property and copies recipients between the Create activity and all
  objects. It then saves the entry in the database.
  """
  @callback create(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Handles additional side effects for the Update ActivityStreams
  type.

  The wrapping callback applies new top-level values on an object to
  the stored objects. Any top-level null literals will be deleted on
  the stored objects as well.
  """
  @callback update(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Delete handles additional side effects for the Delete ActivityStreams
  type.

  The wrapping callback replaces the object(s) with tombstones in the
  database.
  """
  @callback delete(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Follow handles additional side effects for the Follow ActivityStreams
  type.

  The wrapping callback only ensures the 'Follow' has at least one
  'object' entry, but otherwise has no default side effect.
  """
  @callback follow(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Add handles additional side effects for the Add ActivityStreams
  type.

  The wrapping function will add the 'object' IRIs to a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback add(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Remove handles additional side effects for the Remove ActivityStreams
  type.

  The wrapping function will remove all 'object' IRIs from a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback remove(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Like handles additional side effects for the Like ActivityStreams
  type.

  The wrapping function will add the objects on the activity to the
  "liked" collection of this actor.
  """
  @callback like(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Undo handles additional side effects for the Undo ActivityStreams
  type.

  The wrapping function ensures the 'actor' on the 'Undo'
  is be the same as the 'actor' on all Activities being undone.
  It enforces that the actors on the Undo must correspond to all of the
  'object' actors in some manner.

  It is expected that the application will implement the proper
  reversal of activities that are being undone.
  """
  @callback undo(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Block handles additional side effects for the Block ActivityStreams
  type.

  The wrapping callback only ensures the 'Block' has at least one
  'object' entry, but otherwise has no default side effect. It is up
  to the wrapped application function to properly enforce the new
  blocking behavior.

  Note that go-fed does not federate 'Block' activities received in the
  Social API.
  """
  @callback block(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}
end
