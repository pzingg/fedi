defmodule FediServerWeb.ObjectsController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils

  @doc """
  Ref: [AP Section 6.4](https://www.w3.org/TR/activitypub/#delete-activity-outbox)
  If the deleted object is requested the server SHOULD respond with either
  the HTTP 410 Gone status code if a Tombstone object is presented as the
  response body, otherwise respond with a HTTP 404 Not Found.
  """
  def object(%Plug.Conn{request_path: path} = conn, %{"nickname" => _nickname, "ulid" => ulid}) do
    with {:fetch, %{data: data}} when is_map(data) <-
           {:fetch, FediServer.Activities.repo_get(:objects, ulid)},
         status <- check_for_tombstone(data),
         {:ok, body} <- Jason.encode(data) do
      APUtils.send_json_resp(conn, status, body)
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

  def object(%Plug.Conn{} = conn, _params) do
    APUtils.send_json_resp(conn, :not_found)
  end

  defp check_for_tombstone(data) do
    if data["type"] == "Tombstone" do
      :gone
    else
      :ok
    end
  end
end
