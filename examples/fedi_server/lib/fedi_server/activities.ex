defmodule FediServer.Activities do
  @behaviour Fedi.ActivityPub.DatabaseContext

  @doc """
  InboxContains returns true if the OrderedCollection at 'inbox'
  contains the specified 'id'.

  The library makes this call only after acquiring a lock first.
  """
  def inbox_contains(inbox, id) do
    {:error, "Unimplemented"}
  end

  @doc """
  GetInbox returns the first ordered collection page of the outbox at
  the specified IRI, for prepending new items.

  The library makes this call only after acquiring a lock first.
  """
  def get_inbox(inbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  insert_inbox saves a new inbox value.
  """
  def insert_inbox(ordered_collection_page) do
    {:error, "Unimplemented"}
  end

  @doc """
  update_inbox saves the inbox value given from GetInbox, with new items
  prepended by the update_fn. Note that the new items must not be added
  as independent database entries. Separate calls to Create will do that.
  """
  def update_inbox(inbox_iri, update_fn) do
    {:error, "Unimplemented"}
  end

  @doc """
  Owns returns true if the database has an entry for the IRI and it
  exists in the database.

  The library makes this call only after acquiring a lock first.
  """
  def owns(id) do
    {:error, "Unimplemented"}
  end

  @doc """
  ActorForOutbox fetches the actor's IRI for the given outbox IRI.

  The library makes this call only after acquiring a lock first.
  """
  def actor_for_outbox(outbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  ActorForInbox fetches the actor's IRI for the given inbox IRI.

  The library makes this call only after acquiring a lock first.
  """
  def actor_for_inbox(inbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  OutboxForInbox fetches the corresponding actor's outbox IRI for the
  actor's inbox IRI.

  The library makes this call only after acquiring a lock first.
  """
  def outbox_for_inbox(inbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  InboxForActor fetches the inbox corresponding to the given actorIRI.

  It is acceptable to just return nil for the inboxIRI. In this case, the library will
  attempt to resolve the inbox of the actor by remote dereferencing instead.

  The library makes this call only after acquiring a lock first.
  """
  def inbox_for_actor(actor_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Exists returns true if the database has an entry for the specified
  id. It may not be owned by this application instance.

  The library makes this call only after acquiring a lock first.
  """
  def exists(id) do
    {:error, "Unimplemented"}
  end

  @doc """
  Get returns the database entry for the specified id.

  The library makes this call only after acquiring a lock first.
  """
  def get(id) do
    {:error, "Unimplemented"}
  end

  @doc """
  Create adds a new entry to the database which must be able to be
  keyed by its id.

  Note that Activity values received from federated peers may also be
  created in the database this way if the Federating Protocol is
  enabled. The client may freely decide to store only the id instead of
  the entire value.

  The library makes this call only after acquiring a lock first.

  Under certain conditions and network activities, Create may be called
  multiple times for the same ActivityStreams object.
  """
  def create(as_type) do
    {:error, "Unimplemented"}
  end

  @doc """
  Update sets an existing entry to the database based on the value's
  id.

  Note that Activity values received from federated peers may also be
  updated in the database this way if the Federating Protocol is
  enabled. The client may freely decide to store only the id instead of
  the entire value.

  The library makes this call only after acquiring a lock first.
  """
  def update(as_type) do
    {:error, "Unimplemented"}
  end

  @doc """
  Delete removes the entry with the given id.

  Delete is only called for federated objects. Deletes from the Social
  Protocol instead call Update to create a Tombstone.

  The library makes this call only after acquiring a lock first.
  """
  def delete(id) do
    {:error, "Unimplemented"}
  end

  @doc """
  GetOutbox returns the first ordered collection page of the outbox
  at the specified IRI, for prepending new items.

  The library makes this call only after acquiring a lock first.
  """
  def get_outbox(outbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  SetOutbox saves the outbox value given from GetOutbox, with new items
  prepended. Note that the new items must not be added as independent
  database entries. Separate calls to Create will do that.

  The library makes this call only after acquiring a lock first.
  """
  def set_outbox(ordered_collection_page) do
    {:error, "Unimplemented"}
  end

  @doc """
  NewID creates a new IRI id for the provided activity or object. The
  implementation does not need to set the 'id' property and simply
  needs to determine the value.

  The go-fed library will handle setting the 'id' property on the
  activity or object provided with the value returned.
  """
  def new_id(object) do
    {:error, "Unimplemented"}
  end

  @doc """
  Followers obtains the Followers Collection for an actor with the
  given id.

  If modified, the library will then call Update.

  The library makes this call only after acquiring a lock first.
  """
  def followers(actor_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Following obtains the Following Collection for an actor with the
  given id.

  If modified, the library will then call Update.

  The library makes this call only after acquiring a lock first.
  """
  def following(actor_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Liked obtains the Liked Collection for an actor with the
  given id.

  If modified, the library will then call Update.

  The library makes this call only after acquiring a lock first.
  """
  def liked(actor_iri) do
    {:error, "Unimplemented"}
  end
end
