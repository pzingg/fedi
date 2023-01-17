defmodule Fedi.ActivityPub.DatabaseApi do
  @moduledoc """
  A behavior for a context around database operations.
  """

  alias Fedi.ActivityPub.Actor

  @type transport_params() :: Actor.c2s_data() | Actor.s2s_data()

  @doc """
  Returns true if the OrderedCollection at ("/inbox", "/outbox", "/liked", etc.)
  contains the specified 'id'.
  """
  @callback colletion_contains?(inbox :: struct(), coll_id :: URI.t()) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  Returns the ordered collection page ("/inbox", "/outbox", "/liked", etc.)
  at the specified IRI.
  """
  @callback get_collection(coll_id :: URI.t(), opts :: Keyword.t()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

  @doc """
  Updates the ordered collection page ("/inbox", "/outbox", "/liked", etc.)
  the specified IRI, with new items specified in the
  :add member of the the `updates` map prepended.

  Note that the new items must not be added
  as independent database entries. Separate calls to Create will do that.
  """
  @callback update_collection(coll_id :: URI.t(), updates :: map()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

  @doc """
  Returns true if the database has an entry for the IRI and it
  exists in the database.
  """
  @callback owns?(id :: URI.t()) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  Fetches the actor's IRI for the given collection IRI.
  """
  @callback actor_for_collection(coll_id :: URI.t()) ::
              {:ok, actor_iri :: URI.t()} | {:error, term()}

  @doc """
  Fetches the actor's IRI for the given outbox IRI.
  """
  @callback actor_for_outbox(outbox_iri :: URI.t()) ::
              {:ok, actor_iri :: URI.t()} | {:error, term()}

  @doc """
  Fetches the actor's IRI for the given inbox IRI.
  """
  @callback actor_for_inbox(inbox_iri :: URI.t()) ::
              {:ok, actor_iri :: URI.t()} | {:error, term()}

  @doc """
  Fetches the corresponding actor's outbox IRI for the
  actor's inbox IRI.
  """
  @callback outbox_for_inbox(inbox_iri :: URI.t()) ::
              {:ok, outbox_iri :: URI.t()} | {:error, term()}

  @doc """
  Fetches the inbox corresponding to the given actor IRI.

  It is acceptable to just return nil for the inbox IRI. In this case, the library will
  attempt to resolve the inbox of the actor by remote dereferencing instead.
  """
  @callback inbox_for_actor(actor_iri :: URI.t()) ::
              {:ok, inbox_iri :: URI.t()} | {:error, term()}

  @doc """
  Returns true if the database has an entry for the specified
  id. It may not be owned by this application instance.
  """
  @callback exists?(id :: URI.t()) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  Returns the database entry for the specified id.
  """
  @callback get(id :: URI.t()) ::
              {:ok, struct()} | {:error, term()}

  @doc """
  Adds a new entry to the database which must be able to be
  keyed by its id.

  Note that Activity values received from federated peers may also be
  created in the database this way if the Federating Protocol is
  enabled. The client may freely decide to store only the id instead of
  the entire value.

  Under certain conditions and network activities, `create/1` may be called
  multiple times for the same ActivityStreams object.
  """
  @callback create(as_type :: struct()) ::
              {:ok, as_type :: struct(), json :: map() | nil} | {:error, term()}

  @doc """
  Sets an existing entry to the database based on the value's id.

  Note that Activity values received from federated peers may also be
  updated in the database this way if the Federating Protocol is
  enabled. The client may freely decide to store only the id instead of
  the entire value.
  """
  @callback update(as_type :: struct()) ::
              :ok | {:error, term()}

  @doc """
  Removes the entry with the given id.

  `delete` is only called for federated objects. Deletes from the Social
  Protocol instead call `update/1` to create a Tombstone.
  """
  @callback delete(id :: URI.t()) ::
              :ok | {:error, term()}

  @doc """
  Creates a new IRI id for the provided activity or object. The
  implementation does not need to set the 'id' property and simply
  needs to determine the value.

  The library will handle setting the 'id' property on the
  activity or object provided with the value returned.
  """
  @callback new_id(object :: struct()) ::
              {:ok, id :: URI.t()} | {:error, term()}

  @doc """
  Returns a new HTTP Transport on behalf of a specific actor.

  `box_iri` will be either the inbox or outbox of an actor who is
  attempting to do the dereferencing or delivery. Any authentication
  scheme applied on the request must be based on this actor. The
  request must contain some sort of credential of the user, such as a
  HTTP Signature.

  `app_agent` is used by the Transport
  implementation in the User-Agent, as well as the application-specific
  user agent string. The gofedAgent will indicate this library's use as
  well as the library's version number.

  Any server-wide rate-limiting that needs to occur should happen in a
  Transport implementation. This factory function allows this to be
  created, so peer servers are not DOS'd.

  Any retry logic should also be handled by the Transport
  implementation.
  """
  @callback new_transport(box_iri :: URI.t(), app_agent :: String.t()) ::
              {:ok, term()} | {:error, term()}

  # TODO DOC
  @callback dereference(transport :: term(), iri :: URI.t()) ::
              {:ok, map()} | {:error, term()}

  # TODO DOC
  @callback dereference(box_iri :: URI.t(), app_agent :: String.t(), iri :: URI.t()) ::
              {:ok, map()} | {:error, term()}

  # TODO DOC
  @callback deliver(transport :: term(), json_body :: String.t(), iri :: URI.t()) ::
              :ok | {:error, term()}

  # TODO DOC
  @callback deliver(
              box_iri :: URI.t(),
              app_agent :: String.t(),
              json_body :: String.t(),
              iri :: URI.t()
            ) ::
              :ok | {:error, term()}

  # TODO DOC
  @callback batch_deliver(
              transport :: term(),
              json_body :: String.t(),
              recipients :: list()
            ) ::
              :ok | {:error, term()}

  # TODO DOC
  @callback batch_deliver(
              box_iri :: URI.t(),
              app_agent :: String.t(),
              json_body :: String.t(),
              recipients :: list()
            ) ::
              :ok | {:error, term()}
end
