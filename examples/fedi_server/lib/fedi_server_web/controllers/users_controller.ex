defmodule FediServerWeb.UsersController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities

  action_fallback(FediServerWeb.FallbackController)

  def index(conn, _params) do
    users = FediServer.Activities.get_local_users()
    count = Enum.count(users)
    render(conn, "directory.html", users: users, count: count)
  end

  def show(conn, %{"nickname" => nickname} = params) do
    format = get_format(conn)
    user = FediServer.Activities.repo_get(:actors, nickname)

    if format in ["html"] do
      render_profile_and_timeline_html(conn, user, params)
    else
      render_profile_json(conn, user)
    end
  end

  def render_profile_and_timeline_html(conn, %{ap_id: actor_id, data: data}, params)
      when is_map(data) do
    opts = APUtils.collection_opts(params, conn)

    case Activities.get_timeline(actor_id, opts) do
      {:ok, activities} ->
        statuses =
          Enum.map(activities, &FediServerWeb.TimelineHelpers.transform/1)
          |> Enum.reject(&is_nil(&1))

        # TODO: add page=, min_id= max_id=
        # Routes.timelines_url(conn, )
        next = "#"
        previous = nil

        render(conn, "show.html",
          user: data,
          title: "Timeline",
          timeline: statuses,
          count: Enum.count(statuses),
          next: next,
          previous: previous
        )

      {:error, reason} ->
        Logger.error("timeline error #{reason}")
        # FallbackController will handle it
        {:error, :internal_server_error}
    end
  end

  def render_profile_and_timeline_html(_conn, nil, _) do
    # FallbackController will handle it
    {:error, :not_found}
  end

  def render_profile_and_timeline_html(_conn, _, _) do
    # FallbackController will handle it
    {:error, :internal_server_error}
  end

  def render_profile_json(conn, %{data: data}) when is_map(data) do
    case Jason.encode(data) do
      {:ok, body} -> APUtils.send_json_resp(conn, :ok, body)
      {:error, _reason} -> APUtils.send_json_resp(conn, :internal_server_error)
    end
  end

  def render_profile_json(conn, nil) do
    APUtils.send_json_resp(conn, :not_found)
  end

  def render_profile_json(conn, _) do
    APUtils.send_json_resp(conn, :internal_server_error)
  end
end
