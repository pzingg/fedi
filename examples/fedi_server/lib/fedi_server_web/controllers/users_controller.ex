defmodule FediServerWeb.UsersController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils

  def index(conn, _params) do
    users = FediServer.Activities.get_local_users()
    count = Enum.count(users)
    render(conn, "directory.html", users: users, count: count)
  end

  def show(conn, %{"nickname" => nickname}) do
    format = get_format(conn)
    user = FediServer.Activities.repo_get(:actors, nickname)

    if format in ["html"] do
      render_profile_html(user, conn)
    else
      render_profile_json(user, conn)
    end
  end

  def render_profile_html(%{data: data}, conn) when is_map(data) do
    render(conn, "profile.html", user: data)
  end

  def render_profile_html(nil, conn) do
    conn |> put_status(404) |> halt()
  end

  def render_profile_html(_, conn) do
    conn |> put_status(500) |> halt()
  end

  def render_profile_json(%{data: data}, conn) when is_map(data) do
    case Jason.encode(data) do
      {:ok, body} -> APUtils.send_json_resp(conn, :ok, body)
      {:error, _reason} -> APUtils.send_json_resp(conn, :internal_server_error)
    end
  end

  def render_profile_json(nil, conn) do
    APUtils.send_json_resp(conn, :not_found)
  end

  def render_profile_json(_, conn) do
    APUtils.send_json_resp(conn, :internal_server_error)
  end
end
