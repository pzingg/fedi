defmodule Fedi.ActivityPub.FederatingActivityApi do
  @moduledoc """
  These callbacks are called when a new activity is created in
  the Federated Protocol.

  Note that certain types of callbacks will be wrapped with default
  behaviors supported natively by the library.

  For example, implementing a `create/2` activity handler callback
  lets an application dependency inject
  additional behaviors they want to take place, including the default
  behavior supplied by this library. This is guaranteed to be compliant
  with the ActivityPub Federated Protocol.

  Applications are not expected to handle every single ActivityStreams
  type and extension. The unhandled ones are passed to `default_callback/2`.
  """

  alias Fedi.ActivityPub.ActorFacade

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

  @type context() :: ActorFacade.context()
  @type handler_result() :: ActorFacade.s2s_handler_result()

  @doc """
  Handles additional side effects for the Create ActivityStreams
  type, specific to the application.

  The wrapping callback for the Federating Protocol ensures the
  'object' property is created in the database.

  Create calls Create for each object in the federated Activity.
  """
  @callback create(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Update ActivityStreams
  type, specific to the application.

  The wrapping callback for the Federating Protocol ensures the
  'object' property is updated in the database.

  Update calls Update on the federated entry from the database, with a
  new value.
  """
  @callback update(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Delete ActivityStreams
  type, specific to the application.

  Delete removes the federated entry from the database.
  """
  @callback delete(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Follow ActivityStreams
  type, specific to the application.

  The wrapping function can have one of several default behaviors,
  depending on the value of the `on_follow` setting.
  """
  @callback follow(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Accept ActivityStreams
  type, specific to the application.

  The wrapping function determines if this Accept is in response to a
  Follow activity. If so, then the 'actor' is added to the original 'actor's
  'following' collection.

  Otherwise, no side effects are done by go-fed.
  """
  @callback accept(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Reject ActivityStreams
  type, specific to the application.

  The wrapping function has no default side effects. However, if this
  Reject is in response to a Follow then the client MUST NOT go
  forward with adding the 'actor' to the original 'actor's 'following'
  collection by the client application.
  """
  @callback reject(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Add ActivityStreams
  type, specific to the application.

  The wrapping function will add the 'object' IRIs to a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback add(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Remove ActivityStreams
  type, specific to the application.

  The wrapping function will remove all 'object' IRIs from a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback remove(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Like ActivityStreams
  type, specific to the application.

  The wrapping function will add the activity to the 'likes' collection
  on all 'object' targets owned by this server.
  """
  @callback like(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Announce
  ActivityStreams type, specific to the application.

  The wrapping function will add the activity to the 'shares'
  collection on all 'object' targets owned by this server.
  """
  @callback announce(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Undo ActivityStreams
  type, specific to the application.

  The wrapping function ensures the 'actor' on the 'Undo'
  is be the same as the 'actor' on all Activities being undone.
  It enforces that the actors on the Undo must correspond to all of the
  'object' actors in some manner.

  It is expected that the application will implement the proper
  reversal of activities that are being undone.
  """
  @callback undo(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Block ActivityStreams
  type, specific to the application.

  The wrapping function provides no default side effects. It simply
  calls the wrapped function. However, note that Blocks should not be
  received from a federated peer, as delivering Blocks explicitly
  deviates from the original ActivityPub specification.
  """
  @callback block(context :: context(), activity :: struct()) :: handler_result()
end
