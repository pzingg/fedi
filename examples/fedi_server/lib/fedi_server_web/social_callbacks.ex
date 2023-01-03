defmodule FediServerWeb.SocialCallbacks do
  @moduledoc """
  Provides all the Actor actions for our example.
  """

  @behaviour Fedi.ActivityPub.ActorBehavior
  @behaviour Fedi.ActivityPub.SocialProtocol

  require Logger

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

  @doc """
  A no-op for the Social API.
  """
  def default_callback(context, activity) when is_struct(context) and is_struct(activity) do
    {:ok, {activity, get_in(context, [:data, :undeliverable])}}
  end

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
  post_inbox. In this case, the ActorBehavior implementation must not
  write a response to the connection as is expected that the caller
  to post_inbox will do so when handling the error.
  """
  def post_inbox_request_body_hook(actor, %Plug.Conn{} = conn, activity) do
    {:ok, conn}
  end

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
  post_outbox. In this case, the ActorBehavior implementation must not
  write a response to the connection as is expected that the caller
  to post_outbox will do so when handling the error.
  """
  def post_outbox_request_body_hook(actor, %Plug.Conn{} = conn, data) do
    {:ok, conn}
  end

  @doc """
  Delegates the authentication of a POST to an inbox.

  Only called if the Federated Protocol is enabled.

  If an error is returned, it is passed back to the caller of
  post_inbox. In this case, the implementation must not write a
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
  def authenticate_post_inbox(actor, %Plug.Conn{} = conn) do
    {:error, "Unauthenticated"}
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
  def authenticate_get_inbox(actor, %Plug.Conn{} = conn) do
    {:ok, {conn, true}}
  end

  @doc """
  authorize_post_inbox delegates the authorization of an activity that
  has been sent by POST to an inbox.

  Only called if the Federated Protocol is enabled.

  If an error is returned, it is passed back to the caller of
  post_inbox. In this case, the implementation must not write a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authorized' is ignored.

  If no error is returned, but authorization fails, then authorized
  must be false and error nil. It is expected that the implementation
  handles writing to the connection in this case.

  Finally, if the authentication and authorization succeeds, then
  authorized must be true and error nil. The request will continue
  to be processed.
  """
  def authorize_post_inbox(actor, %Plug.Conn{} = conn, activity) do
    {:ok, {conn, true}}
  end

  @doc """
  post_inbox delegates the side effects of adding to the inbox and
  determining if it is a request that should be blocked.

  Only called if the Federated Protocol is enabled.

  As a side effect, post_inbox sets the federated data in the inbox, but
  not on its own in the database, as inbox_forwarding (which is called
  later) must decide whether it has seen this activity before in order
  to determine whether to do the forwarding algorithm.

  If the error is ErrObjectRequired or ErrTargetRequired, then a Bad
  Request status is sent in the response.
  """
  def post_inbox(actor, %URI{} = inbox_iri, activity) do
    :ok
  end

  @doc """
  inbox_forwarding delegates inbox forwarding logic when a POST request
  is received in the Actor's inbox.

  Only called if the Federated Protocol is enabled.

  The delegate is responsible for determining whether to do the inbox
  forwarding, as well as actually conducting it if it determines it
  needs to.

  As a side effect, inbox_forwarding must set the federated data in the
  database, independently of the inbox, however it sees fit in order to
  determine whether it has seen the activity before.

  The provided url is the inbox of the recipient of the Activity. The
  Activity is examined for the information about who to inbox forward
  to.

  If an error is returned, it is returned to the caller of post_inbox.
  """
  def inbox_forwarding(actor, %URI{} = inbox_iri, activity) do
    # NEED IMPL
    :ok
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
  def post_outbox(actor, activity, %URI{} = outbox_iri, raw_json) do
    # TODO IMPL
    Logger.error("SocialCallbacks post_outbox")
    {:ok, true}
  end

  @doc """
  add_new_ids sets new URL ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  def add_new_ids(actor, activity) do
    # NEED IMPL
    {:ok, activity}
  end

  @doc """
  deliver sends a federated message. Called only if federation is
  enabled.

  Called if the Federated Protocol is enabled.

  The provided url is the outbox of the sender. The Activity contains
  the information about the intended recipients.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  def deliver(actor, %URI{} = outbox, activity) do
    # :ok
    {:error, "We are not a federated instance, unable to deliver #{inspect(activity.__struct__)}"}
  end

  @doc """
  Delegates the authentication and authorization of a POST to an outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  post_outbox. In this case, the implementation must not write a
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
  def authenticate_post_outbox(actor, %Plug.Conn{} = conn) do
    {:ok, {conn, true}}
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
  def authenticate_get_outbox(actor, %Plug.Conn{} = conn) do
    {:ok, {conn, true}}
  end

  @doc """
  wrap_in_create wraps the provided object in a Create ActivityStreams
  activity. The provided URL is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  def wrap_in_create(actor, value, %URI{} = outbox_iri) do
    # {:ok, create}
    {:error, "Unimplemented"}
  end

  @doc """
  Returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  authenticate_get_outbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  def get_outbox(actor, %Plug.Conn{} = conn) do
    with {:ok, oc} <- @mock_ordered_collection_page do
      {:ok, {conn, oc}}
    end
  end

  @doc """
  Returns the OrderedCollection inbox of the actor for this
  context. It is up to the implementation to provide the correct
  collection for the kind of authorization given in the request.

  authenticate_get_inbox will be called prior to this.

  Always called, regardless whether the Federated Protocol or Social
  API is enabled.
  """
  def get_inbox(actor, %Plug.Conn{} = conn) do
    with {:ok, oc} <- @mock_ordered_collection_page do
      {:ok, {conn, oc}}
    end
  end

  def mock_ordered_collection_json() do
    Jason.decode!(@mock_ordered_collection_json)
  end
end
