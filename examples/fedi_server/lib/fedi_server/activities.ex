defmodule FediServer.Activities do
  @behaviour Fedi.ActivityPub.DatabaseContext

  require Logger

  def server_host, do: "http://example.social"

  alias Fedi.ActivityStreams.Type.OrderedCollectionPage

  alias FediServer.Activities.User
  alias FediServer.Activities.Activity
  alias FediServer.Activities.Object
  alias FediServer.Repo

  @doc """
  Returns true if the OrderedCollection at 'inbox'
  contains the specified 'id'.
  """
  def inbox_contains(inbox, id) do
    {:error, "Unimplemented"}
  end

  @doc """
  Returns the first ordered collection page of the inbox at
  the specified IRI, for prepending new items.
  """
  def get_inbox(inbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Saves a new inbox value.
  """
  def insert_inbox(ordered_collection_page) do
    {:error, "Unimplemented"}
  end

  @doc """
  Saves the first ordered collection page of the inbox at
  the specified IRI, with new items prepended by the update_fn.
  Note that the new items must not be added
  as independent database entries. Separate calls to Create will do that.
  """
  def update_inbox(inbox_iri, update_fn) do
    {:error, "Unimplemented"}
  end

  @doc """
  Returns true if the database has an entry for the IRI and it
  exists in the database.

  Used in federated SideEffectActor and Activity callbacks.
  """
  def owns(id) do
    {:error, "Unimplemented"}
  end

  @doc """
  Fetches the actor's IRI for the given outbox IRI.

  Used in federated SideEffectActor and `like` Activity callbacks.
  """
  def actor_for_outbox(outbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Fetches the actor's IRI for the given inbox IRI.

  Used in federated `accept` and `follow` Activity callbacks.
  """
  def actor_for_inbox(inbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Fetches the corresponding actor's outbox IRI for the
  actor's inbox IRI.
  """
  def outbox_for_inbox(inbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Fetches the inbox corresponding to the given actor IRI.

  It is acceptable to just return nil. In this case, the library will
  attempt to resolve the inbox of the actor by remote dereferencing instead.
  """
  def inbox_for_actor(actor_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Returns true if the database has an entry for the specified
  id. It may not be owned by this application instance.

  Used in federated SideEffectActor.
  """
  def exists(id) do
    {:error, "Unimplemented"}
  end

  @doc """
  Returns the database entry for the specified id.
  """
  def get(id) do
    {:error, "Unimplemented"}
  end

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
  def create(as_type) do
    {:error, "Unimplemented"}
  end

  @doc """
  Sets an existing entry to the database based on the value's id.

  Note that Activity values received from federated peers may also be
  updated in the database this way if the Federating Protocol is
  enabled. The client may freely decide to store only the id instead of
  the entire value.
  """
  def update(as_type) do
    {:error, "Unimplemented"}
  end

  @doc """
  Removes the entry with the given id.

  delete is only called for federated objects. Deletes from the Social
  Protocol instead call Update to create a Tombstone.
  """
  def delete(id) do
    {:error, "Unimplemented"}
  end

  @doc """
  Returns the first ordered collection page of the outbox
  at the specified IRI, for prepending new items.

  Used in social SideEffectActor post_outbox.
  """
  def get_outbox(outbox_iri) do
    {:error, "Unimplemented"}
  end

  @doc """
  Saves a new outbox value.
  """
  def insert_outbox(ordered_collection_page) do
    {:error, "Unimplemented"}
  end

  @doc """
  Saves the first ordered collection page of the outbox at
  the specified IRI, with new items prepended by the update_fn.

  Note that the new items must not be added as independent
  database entries. Separate calls to Create will do that.

  Used in social SideEffectActor post_outbox.
  """
  def update_outbox(outbox_iri, update_fn) do
    {:error, "Unimplemented"}
  end

  @doc """
  Creates a new IRI id for the provided activity or object. The
  implementation does not need to set the 'id' property and simply
  needs to determine the value.

  The library will handle setting the 'id' property on the
  activity or object provided with the value returned.

  Used in social SideEffectActor post_inbox.
  """
  def new_id(object) do
    {:error, "Unimplemented"}
  end

  @doc """
  Obtains the Followers Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  def followers(actor_iri) do
    {:ok, OrderedCollectionPage.new()}
  end

  @doc """
  Obtains the Following Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  def following(actor_iri) do
    {:ok, OrderedCollectionPage.new()}
  end

  @doc """
  Obtains the Liked Collection for an actor with the given id.

  If modified, the library will then call Update.
  """
  def liked(actor_iri) do
    {:ok, OrderedCollectionPage.new()}
  end
end
