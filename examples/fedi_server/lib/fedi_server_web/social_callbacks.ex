defmodule FediServerWeb.SocialCallbacks do
  @moduledoc """
  Provides all the Social API logic for our example.
  """

  @behaviour Fedi.ActivityPub.CommonApi
  @behaviour Fedi.ActivityPub.SocialApi
  @behaviour Fedi.ActivityPub.SocialActivityApi

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities
  alias FediServer.Activities.User
  alias FediServerWeb.CommonCallbacks

  @impl true
  defdelegate authenticate_get_inbox(context, conn), to: CommonCallbacks

  @impl true
  defdelegate get_inbox(context, conn, params), to: CommonCallbacks

  @impl true
  defdelegate authenticate_get_outbox(context, conn), to: CommonCallbacks

  @impl true
  defdelegate get_outbox(context, conn, params), to: CommonCallbacks

  @impl true
  defdelegate post_outbox(context, activity, outbox_iri, raw_json), to: CommonCallbacks

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
  send a response to the connection as is expected that the caller
  to post_outbox will do so when handling the error.
  """
  @impl true
  def post_outbox_request_body_hook(_context, %Plug.Conn{} = conn, _activity) do
    {:ok, conn}
  end

  @doc """
  Sets new ids on the activity. It also does so for all
  'object' properties if the Activity is a Create type.

  Only called if the Social API is enabled.

  If an error is returned, it is returned to the caller of post_outbox.
  """
  @impl true
  def add_new_ids(context, activity) do
    # Handled by SideEffectActor.
    {:error, "Unexpected"}
  end

  @doc """
  Delegates the authentication and authorization of a POST to an outbox.

  Only called if the Social API is enabled.

  If an error is returned, it is passed back to the caller of
  post_outbox. In this case, the implementation must not send a
  response to the connection as is expected that the client will
  do so when handling the error. The 'authenticated' is ignored.

  If no error is returned, but authentication or authorization fails,
  then authenticated must be false and error nil. It is expected that
  the implementation handles sending a response to the connection in this
  case.

  Finally, if the authentication and authorization succeeds, then
  authenticated must be true and error nil. The request will continue
  to be processed.
  """
  @impl true
  def authenticate_post_outbox(context, %Plug.Conn{} = conn) do
    {:ok, conn, true}
  end

  @doc """
  Wraps the provided object in a Create ActivityStreams
  activity. `outbox_iri` is the actor's outbox endpoint.

  Only called if the Social API is enabled.
  """
  @impl true
  def wrap_in_create(context, value, %URI{} = outbox_iri) do
    # Handled by SideEffectActor.
    {:error, "Unexpected"}
  end

  @doc """
  A no-op for the Social API.
  """
  @impl true
  def default_callback(_context, _activity) do
    :pass
  end

  ### Activity handlers

  @doc """
  Create a following relationship.
  """
  @impl true
  def follow(context, activity) do
    with {:activity_actor, actor} <- {:activity_actor, Utils.get_actor(activity)},
         {:activity_object, object} <- {:activity_object, Utils.get_object(activity)},
         {:follower_id, %URI{} = follower_id} <- {:follower_id, APUtils.to_id(actor)},
         {:following_id, %URI{} = following_id} <- {:following_id, APUtils.to_id(object)},
         {:ok, %User{}} <- Activities.ensure_user(follower_id, true),
         # Insert remote following user if not in db
         {:ok, %User{}} <- Activities.ensure_user(following_id, false),
         {:ok, relationship} <- Activities.follow(follower_id, following_id, :pending) do
      Logger.debug("Inserted new relationship")
      {:ok, activity, false}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Insert error #{Activities.describe_errors(changeset)}")
        {:error, "Internal database error"}

      {:error, reason} ->
        Logger.error("Follow error #{reason}")
        {:error, reason}

      {:activity_actor, _} ->
        Utils.err_actor_required(activity: activity)

      {:activity_object, _} ->
        Utils.err_object_required(activity: activity)

      {:follower_id, _} ->
        {:error, "No id in actor"}

      {:following_id, _} ->
        {:error, "No id in object"}
    end
  end
end
