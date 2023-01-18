defmodule FediServerWeb.FollowingController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities

  def following(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    # TODO Check authentication and authorization
    handle_collection(conn, actor, params)
  end

  def followers(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    # TODO Check authentication and authorization
    handle_collection(conn, actor, params)
  end

  def handle_collection(conn, _actor, params) do
    %URI{path: path} = coll_id = APUtils.request_id(conn)

    with {:ok, coll} <- Activities.get_collection(coll_id, APUtils.collection_opts(params)),
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
