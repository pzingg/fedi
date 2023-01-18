defmodule Fedi.ActivityPub.SocialActivityApi do
  @moduledoc """
  These callbacks are called when a new activity is created in
  the Social API.

  Note that certain types of callbacks will be 'wrapped' with default
  behaviors supported natively by the library.

  For example, implementing a `create/2` activity handler callback
  lets an application dependency inject
  additional behaviors they want to take place, including the default
  behavior supplied by this library. This is guaranteed to be compliant
  with the ActivityPub Social API.

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

  @type context() :: ActorFacade.c2s_context()
  @type handler_result() :: ActorFacade.c2s_handler_result()

  @doc """
  Handles additional side effects for the Create ActivityStreams
  type.

  The wrapping callback copies the actor(s) to the 'attributedTo'
  property and copies recipients between the Create activity and all
  objects. It then saves the entry in the database.
  """
  @callback create(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Update ActivityStreams
  type.

  The wrapping callback applies new top-level values on an object to
  the stored objects. Any top-level null literals will be deleted on
  the stored objects as well.
  """
  @callback update(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Delete ActivityStreams
  type.

  The wrapping callback replaces the object(s) with tombstones in the
  database.
  """
  @callback delete(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Follow ActivityStreams
  type.

  The wrapping callback only ensures the 'Follow' has at least one
  'object' entry, but otherwise has no default side effect.
  """
  @callback follow(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Add ActivityStreams
  type.

  The wrapping function will add the 'object' IRIs to a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback add(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Remove ActivityStreams
  type.

  The wrapping function will remove all 'object' IRIs from a specific
  'target' collection if the 'target' collection(s) live on this
  server.
  """
  @callback remove(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Like ActivityStreams
  type.

  The wrapping function will add the objects on the activity to the
  "liked" collection of this actor.
  """
  @callback like(context :: context(), activity :: struct()) :: handler_result()

  @doc """
  Handles additional side effects for the Undo ActivityStreams
  type.

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
  type.

  The wrapping callback only ensures the 'Block' has at least one
  'object' entry, but otherwise has no default side effect. It is up
  to the wrapped application function to properly enforce the new
  blocking behavior.

  Note that the library does not federate 'Block' activities received in the
  Social API.
  """
  @callback block(context :: context(), activity :: struct()) :: handler_result()
end
