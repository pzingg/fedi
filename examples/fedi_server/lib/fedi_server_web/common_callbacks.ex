defmodule FediServerWeb.CommonCallbacks do
  @moduledoc """
  Provides all the Common logic for our example.
  """

  @behaviour Fedi.ActivityPub.CommonApi

  @mock_ordered_collection_json """
  {
    "@context": "https://www.w3.org/ns/activitystreams",
    "id": "http://example.org/users/sally?page=1",
    "orderedItems": [
    {
      "type": "Create",
      "id": "http://example.org/users/sally/1/activity",
      "actor": "http://example.org/users/sally",
      "to": "https://www.w3.org/ns/activitystreams#Public",
      "object": {
        "name": "A Simple Note",
        "type": "Note",
        "id": "http://example.org/users/sally/1",
        "to": "https://www.w3.org/ns/activitystreams#Public",
        "attributedTo": "http://example.org/users/sally"
      }
    },
    {
      "type": "Create",
      "id": "http://example.org/users/sally/2/activity",
      "actor": "http://example.org/users/sally",
      "to": "https://www.w3.org/ns/activitystreams#Public",
      "object":
      {
        "name": "Another Simple Note",
        "type": "Note",
        "id": "http://example.org/users/sally/2",
        "to": "https://www.w3.org/ns/activitystreams#Public",
        "attributedTo": "http://example.org/users/sally"
      }
    }
    ],
    "partOf": "http://example.org/users/sally",
    "summary": "Page 1 of Sally's notes",
    "type": "OrderedCollectionPage"
  }
  """

  @mock_ordered_collection_page Fedi.Streams.JSONResolver.resolve(@mock_ordered_collection_json)

  ### Implementation

  def mock_ordered_collection_json() do
    Jason.decode!(@mock_ordered_collection_json)
  end

  @doc """
  Delegates the authentication of a GET to an inbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.

  If an error is returned, it is passed back to the caller of
  GetInbox. In this case, the implementation must not write a
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
  def authenticate_get_inbox(context, %Plug.Conn{} = conn) do
    # TODO IMPL
    {:ok, {conn, true}}
  end

  @doc """
  Returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  authenticate_get_inbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  def get_inbox(context, %Plug.Conn{} = conn) do
    # TODO IMPL
    with {:ok, oc} <- @mock_ordered_collection_page do
      {:ok, {conn, oc}}
    end
  end

  @doc """
  Delegates the authentication of a GET to an outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.

  If an error is returned, it is passed back to the caller of
  get_outbox. In this case, the implementation must not write a
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
  def authenticate_get_outbox(context, %Plug.Conn{} = conn) do
    # TODO IMPL
    {:ok, {conn, true}}
  end

  @doc """
  Returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  authenticate_get_outbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  def get_outbox(context, %Plug.Conn{} = conn) do
    # TODO IMPL
    with {:ok, oc} <- @mock_ordered_collection_page do
      {:ok, {conn, oc}}
    end
  end

  @doc """
  post_outbox delegates the logic for side effects and adding to the
  outbox.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled. In the case of the Social API being enabled, side
  effects of the Activity must occur.

  The delegate is responsible for adding the activity to the database's
  general storage for independent retrieval, and not just within the
  actor's outbox.

  If the error is ErrObjectRequired or ErrTargetRequired, then a Bad
  Request status is sent in the response.

  Note that 'raw_json' is an unfortunate consequence where an 'Update'
  Activity is the only one that explicitly cares about 'null' values in
  JSON. Since go-fed does not differentiate between 'null' values and
  values that are simply not present, the 'raw_json' map is ONLY needed
  for this narrow and specific use case.
  """
  def post_outbox(context, activity, %URI{} = outbox_iri, raw_json) do
    # TODO IMPL
    {:ok, true}
  end
end
