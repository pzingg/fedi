defmodule FediServerWeb.SocialCallbacks do
  @moduledoc """
  Provides all the Social API logic for our example.
  """

  @behaviour Fedi.ActivityPub.CommonApi
  @behaviour Fedi.ActivityPub.SocialApi

  require Logger

  alias FediServerWeb.CommonCallbacks

  defdelegate authenticate_get_inbox(context, conn), to: CommonCallbacks

  defdelegate get_inbox(context, conn, params), to: CommonCallbacks

  defdelegate authenticate_get_outbox(context, conn), to: CommonCallbacks

  defdelegate get_outbox(context, conn, params), to: CommonCallbacks

  defdelegate post_outbox(context, activity, outbox_iri, raw_json), to: CommonCallbacks

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
  def post_inbox_request_body_hook(context, %Plug.Conn{} = conn, activity) do
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
  def post_outbox_request_body_hook(context, %Plug.Conn{} = conn, data) do
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
  def authenticate_post_inbox(context, %Plug.Conn{} = conn) do
    {:error, "Unauthenticated"}
  end

  @doc """
  add_new_ids sets new URL ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  def add_new_ids(context, activity) do
    # NEED IMPL
    {:ok, activity}
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
  def authenticate_post_outbox(context, %Plug.Conn{} = conn) do
    {:ok, conn, true}
  end

  @doc """
  wrap_in_create wraps the provided object in a Create ActivityStreams
  activity. The provided URL is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  def wrap_in_create(context, value, %URI{} = outbox_iri) do
    # {:ok, create}
    {:error, "Unimplemented"}
  end

  @doc """
  A no-op for the Social API.
  """
  def default_callback(_context, _activity) do
    :pass
  end
end
