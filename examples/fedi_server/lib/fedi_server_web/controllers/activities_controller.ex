defmodule FediServerWeb.ActivitiesController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils

  def activity(%Plug.Conn{request_path: path} = conn, %{"nickname" => _nickname, "ulid" => ulid}) do
    with {:fetch, %{data: data}} when is_map(data) <-
           {:fetch, FediServer.Activities.repo_get(:activities, ulid)},
         {:ok, body} <- Jason.encode(data) do
      APUtils.send_json_resp(conn, :ok, body)
    else
      {:fetch, nil} ->
        APUtils.send_json_resp(conn, :not_found)

      {:fetch, other} ->
        Logger.error("No json data in #{inspect(other)}")
        APUtils.send_json_resp(conn, :internal_server_error)

      {:error, reason} ->
        Logger.error("Encoding error #{inspect(reason)}")
        APUtils.send_json_resp(conn, :internal_server_error)
    end
  end

  def activity(%Plug.Conn{} = conn, _params) do
    APUtils.send_json_resp(conn, :not_found)
  end
end
