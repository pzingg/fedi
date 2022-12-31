defmodule Fedi.ActivityPub.FederatingProtocol do
  @moduledoc """
  FederatingProtocol contains behaviors an application needs to satisfy for the
  full ActivityPub S2S implementation to be supported by this library.

  It is only required if the client application wants to support the server-to-
  server, or federating, protocol.

  It is passed to the library as a dependency injection from the client
  application.

  Note that certain types of callbacks will be 'wrapped' with default
  behaviors supported natively by the library. Other callbacks
  compatible with streams.TypeResolver can be specified by 'other'.

  For example, setting the 'Create' field in the
  FederatingWrappedCallbacks lets an application dependency inject
  additional behaviors they want to take place, including the default
  behavior supplied by this library. This is guaranteed to be compliant
  with the ActivityPub Social protocol.

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
    on_follow: 2,
    accept: 2,
    reject: 2,
    add: 2,
    remove: 2,
    like: 2,
    announce: 2,
    undo: 2,
    block: 2
  ]

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
              actor :: struct(),
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
  @callback authenticate_post_inbox(actor :: struct(), request :: Plug.Conn.t()) ::
              {:ok, {response :: Plug.Conn.t(), authenticated :: boolean()}} | {:error, term()}

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
  @callback blocked(actor :: struct(), actor_iris :: list) :: {:ok, boolean()} | {:error, term()}

  @doc """
  MaxInboxForwardingRecursionDepth determines how deep to search within
  an activity to determine if inbox forwarding needs to occur.

  Zero or negative numbers indicate infinite recursion.
  """
  @callback max_inbox_forwarding_recursion_depth(actor :: struct()) :: integer()

  @doc """
  MaxDeliveryRecursionDepth determines how deep to search within
  collections owned by peers when they are targeted to receive a
  delivery.

  Zero or negative numbers indicate infinite recursion.
  """
  @callback max_delivery_recursion_depth(actor :: struct()) :: integer()

  @doc """
  FilterForwarding allows the implementation to apply business logic
  such as blocks, spam filtering, and so on to a list of potential
  Collections and OrderedCollections of recipients when inbox
  forwarding has been triggered.

  The activity is provided as a reference for more intelligent
  logic to be used, but the implementation must not modify it.
  """
  @callback filter_forwarding(actor :: struct(), recipients :: list(), activity :: struct()) ::
              {:ok, recipients :: list()} | {:error, term()}

  @doc """
  GetInbox returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  AuthenticateGetInbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  @callback get_inbox(actor :: struct(), request :: Plug.Conn.t()) ::
              {:ok, ordered_collection_page :: term()} | {:error, term()}

  @doc """
  new_type_resolver creates a new Resolver that examines the type of an
  ActivityStream value to determine what callback function to pass the
  concretely typed value. The callback is guaranteed to receive a value whose
  underlying ActivityStreams type matches the concrete interface name in its
  signature.
  """
  @callback new_type_resolver(
              actor :: struct(),
              inbox_iri :: URI.t(),
              activity :: term(),
              other :: term()
            ) ::
              :ok | {:error, term()}

  @doc """
  DefaultCallback is called for types that go-fed can deserialize but
  are not handled by the application's callbacks returned in the
  Callbacks method.

  Applications are not expected to handle every single ActivityStreams
  type and extension, so the unhandled ones are passed to
  DefaultCallback.
  """
  @callback default_callback(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Create handles additional side effects for the Create ActivityStreams
  type, specific to the application using go-fed.

  The wrapping callback for the Federating Protocol ensures the
  'object' property is created in the database.

  Create calls Create for each object in the federated Activity.
  """
  @callback create(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Update handles additional side effects for the Update ActivityStreams
  type, specific to the application using go-fed.

  The wrapping callback for the Federating Protocol ensures the
  'object' property is updated in the database.

  Update calls Update on the federated entry from the database, with a
  new value.
  """
  @callback update(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Delete handles additional side effects for the Delete ActivityStreams
  type, specific to the application using go-fed.

  Delete removes the federated entry from the database.
  """
  @callback delete(actor :: struct(), ctivity :: struct()) :: :ok | {:error, term()}

  @doc """
  Follow handles additional side effects for the Follow ActivityStreams
  type, specific to the application using go-fed.

  The wrapping function can have one of several default behaviors,
  depending on the value of the OnFollow setting.
  """
  @callback follow(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  OnFollow determines what action to take for this particular callback
  if a Follow Activity is handled.
  """
  @callback on_follow(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Accept handles additional side effects for the Accept ActivityStreams
  type, specific to the application using go-fed.

  The wrapping function determines if this 'Accept' is in response to a
  'Follow'. If so, then the 'actor' is added to the original 'actor's
  'following' collection.

  Otherwise, no side effects are done by go-fed.
  """
  @callback accept(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Reject handles additional side effects for the Reject ActivityStreams
  type, specific to the application using go-fed.

  The wrapping function has no default side effects. However, if this
  'Reject' is in response to a 'Follow' then the client MUST NOT go
  forward with adding the 'actor' to the original 'actor's 'following'
  collection by the client application.
  """
  @callback reject(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Add handles additional side effects for the Add ActivityStreams
  type, specific to the application using go-fed.

  The wrapping function will add the 'object' IRIs to a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback add(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Remove handles additional side effects for the Remove ActivityStreams
  type, specific to the application using go-fed.

  The wrapping function will remove all 'object' IRIs from a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback remove(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Like handles additional side effects for the Like ActivityStreams
  type, specific to the application using go-fed.

  The wrapping function will add the activity to the "likes" collection
  on all 'object' targets owned by this server.
  """
  @callback like(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Announce handles additional side effects for the Announce
  ActivityStreams type, specific to the application using go-fed.

  The wrapping function will add the activity to the "shares"
  collection on all 'object' targets owned by this server.
  """
  @callback announce(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}

  @doc """
  Undo handles additional side effects for the Undo ActivityStreams
  type, specific to the application using go-fed.

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
  type, specific to the application using go-fed.

  The wrapping function provides no default side effects. It simply
  calls the wrapped function. However, note that Blocks should not be
  received from a federated peer, as delivering Blocks explicitly
  deviates from the original ActivityPub specification.
  """
  @callback block(actor :: struct(), activity :: struct()) :: :ok | {:error, term()}
end
