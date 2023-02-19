defmodule FediServerWeb.UsersController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Accounts.User
  alias FediServer.Activities
  alias FediServerWeb.TimelineHelpers

  action_fallback(FediServerWeb.FallbackController)

  def index(conn, _params) do
    users =
      FediServer.Activities.get_local_users()
      |> Enum.map(fn %{data: user_data} -> TimelineHelpers.get_actor_info(user_data) end)

    count = Enum.count(users)
    render(conn, "directory.html", users: users, count: count)
  end

  def show(conn, %{"nickname" => nickname} = params) do
    user = FediServer.Activities.repo_get(:actors, nickname)

    if get_format(conn) == "html" do
      render_profile_and_timeline_html(conn, user, params)
    else
      render_profile_json(conn, user)
    end
  end

  def render_profile_and_timeline_html(
        conn,
        %User{ap_id: actor_id, data: user_data} = user,
        params
      )
      when is_map(user_data) do
    opts =
      params
      |> Map.put("page", "true")
      |> APUtils.collection_opts(conn)

    case Activities.get_timeline(actor_id, opts) do
      {:ok, activities} ->
        statuses =
          Enum.map(activities, &TimelineHelpers.transform/1)
          |> Enum.reject(&is_nil(&1))

        render(conn, "show.html",
          user: TimelineHelpers.get_actor_info(user_data),
          title: "Timeline",
          timeline: statuses,
          count: Enum.count(statuses),
          max_id: Map.get(params, "max_id"),
          next: TimelineHelpers.next_url(Routes.users_url(conn, :show, user), statuses)
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

  def render_profile_json(conn, %User{data: data}) do
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
