defmodule FediServerWeb.FollowingController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities

  def following(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    # TODO Check authentication and authorization
    %URI{path: path} = request_iri = APUtils.request_id(conn)

    with {:ok, actor_iri} <-
           %URI{request_iri | path: String.replace(path, "/following", "/outbox")}
           |> Activities.actor_for_outbox(),
         {:ok, coll} <- Activities.get_following_page(actor_iri),
         {:ok, m} <- Fedi.Streams.Serializer.serialize(coll),
         {:ok, body} <- Jason.encode(m) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    else
      {:error, reason} ->
        Logger.error("following error #{reason}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, "Internal server error")
    end
  end

  def followers(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    # TODO Check authentication and authorization
    %URI{path: path} = request_iri = APUtils.request_id(conn)

    with {:ok, actor_iri} <-
           %URI{request_iri | path: String.replace(path, "/followers", "/outbox")}
           |> Activities.actor_for_outbox(),
         {:ok, coll} <- Activities.get_followers_page(actor_iri),
         {:ok, m} <- Fedi.Streams.Serializer.serialize(coll),
         {:ok, body} <- Jason.encode(m) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    else
      {:error, reason} ->
        Logger.error("followers error #{reason}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, "Internal server error")
    end
  end
end
