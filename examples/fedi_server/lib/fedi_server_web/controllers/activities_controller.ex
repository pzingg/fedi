defmodule FediServerWeb.ActivitiesController do
  use FediServerWeb, :controller

  require Logger

  @doc """
  Ref: [AP Section 6.4](https://www.w3.org/TR/activitypub/#delete-activity-outbox)
  If the deleted object is requested the server SHOULD respond with either
  the HTTP 410 Gone status code if a Tombstone object is presented as the
  response body, otherwise respond with a HTTP 404 Not Found.
  """
  def activity(%Plug.Conn{request_path: path} = conn, %{"nickname" => _nickname, "ulid" => ulid}) do
    with {:fetch, %{data: data}} when is_map(data) <-
           {:fetch, FediServer.Activities.repo_get(:activities, ulid)},
         {:ok, body} <- Jason.encode(data) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    else
      {:fetch, nil} ->
        send_resp(conn, 404, "Not found")

      {:fetch, other} ->
        Logger.error("No json data in #{inspect(other)}")
        send_resp(conn, 500, "Internal system error")

      {:error, reason} ->
        Logger.error("Encoding error #{inspect(reason)}")
        send_resp(conn, 500, "Internal system error")
    end
  end

  def activity(%Plug.Conn{} = conn, _params) do
    send_resp(conn, 404, "Not found")
  end
end
