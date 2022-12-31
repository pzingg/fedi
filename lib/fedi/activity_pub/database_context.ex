defmodule Fedi.ActivityPub.DatabaseContext do
  @moduledoc """
  A behavior for a context around database operations.
  """

  @doc """
  Returns true if the OrderedCollection at 'inbox'
  contains the specified 'id'.
  """
  @callback inbox_contains(inbox :: struct(), id :: URI.t()) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  Returns the first ordered collection page of the inbox at
  the specified IRI, for prepending new items.
  """
  @callback get_inbox(inbox_iri :: URI.t()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

  @doc """
  Inserts a new inbox value.
  """
  @callback insert_inbox(ordered_collection_page :: struct()) ::
              :ok | {:error, term()}

  @doc """
  Saves the first ordered collection page of the inbox at
  the specified IRI with new items prepended by the update_fn.
  Note that the new items must not be added
  as independent database entries. Separate calls to Create will do that.
  """
  @callback update_inbox(inbox_iri :: URI.t(), update_fn :: function()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

  @doc """
  Returns true if the database has an entry for the IRI and it
  exists in the database.
  """
  @callback owns(id :: URI.t()) ::
              {:ok, boolean()} | {:error, term()}

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
  @callback exists(id :: URI.t()) ::
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

  Under certain conditions and network activities, Create may be called
  multiple times for the same ActivityStreams object.
  """
  @callback create(as_type :: struct()) ::
              :ok | {:error, term()}

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
  Delete removes the entry with the given id.

  Delete is only called for federated objects. Deletes from the Social
  Protocol instead call Update to create a Tombstone.

  The library makes this call only after acquiring a lock first.
  """
  @callback delete(id :: URI.t()) ::
              :ok | {:error, term()}

  @doc """
  GetOutbox returns the first ordered collection page of the outbox
  at the specified IRI, for prepending new items.

  The library makes this call only after acquiring a lock first.
  """
  @callback get_outbox(outbox_iri :: URI.t()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

  @doc """
  Saves a new outbox value.
  """
  @callback insert_outbox(ordered_collection_page :: struct()) ::
              :ok | {:error, term()}

  @doc """
  Saves the first ordered collection page of the outbox at
  the specified IRI, with new items prepended by the update_fn.

  Note that the new items must not be added as independent
  database entries. Separate calls to Create will do that.
  """
  @callback update_outbox(inbox_iri :: URI.t(), update_fn :: function()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

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
  Obtains the Followers Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  @callback followers(actor_iri :: URI.t()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

  @doc """
  Obtains the Following Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  @callback following(actor_iri :: URI.t()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}

  @doc """
  Obtains the Liked Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  @callback liked(actor_iri :: URI.t()) ::
              {:ok, ordered_collection_page :: struct()} | {:error, term()}
end
