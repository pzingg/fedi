defmodule FediServerWeb.UsersController do
  use FediServerWeb, :controller

  require Logger

  def profile(%Plug.Conn{request_path: path} = conn, %{"nickname" => nickname}) do
    with {:fetch, %{data: data}} when is_map(data) <-
           {:fetch, FediServer.Activities.repo_get(:actors, nickname)},
         {:ok, body} <- Jason.encode(data) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, body)
    else
      {:fetch, nil} ->
        send_resp(conn, 404, "Not found")

      {:fetch, other} ->
        Logger.error("No json data in #{inspect(other)}")

        send_resp(conn, 500, "Internal server error")

      {:error, reason} ->
        Logger.error("Encoding error #{inspect(reason)}")

        send_resp(conn, 500, "Internal server error")
    end
  end

  def profile(%Plug.Conn{} = conn, _params) do
    send_resp(conn, 404, "Not found")
  end
end
