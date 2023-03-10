defmodule FediServerWeb.FollowingController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities

  def following(conn, %{"nickname" => _nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    # TODO Check authentication and authorization
    handle_collection(conn, actor, params)
  end

  def followers(conn, %{"nickname" => _nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    # TODO Check authentication and authorization
    handle_collection(conn, actor, params)
  end

  def handle_collection(conn, _actor, params) do
    coll_id = APUtils.request_id(conn)
    opts = APUtils.collection_opts(params, conn)

    with {:ok, coll} <- Activities.get_collection(coll_id, opts),
         {:ok, m} <- Fedi.Streams.Serializer.serialize(coll),
         {:ok, body} <- Jason.encode(m) do
      APUtils.send_json_resp(conn, :ok, body)
    else
      {:error, reason} ->
        Logger.error("followers error #{reason}")
        APUtils.send_json_resp(conn, :internal_server_error)
    end
  end
end
