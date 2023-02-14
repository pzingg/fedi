defmodule FediServerWeb.TimelinesController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Accounts.User
  alias FediServer.Activities
  alias FediServer.HTTPClient

  # action_fallback(FediServerWeb.FallbackController)

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def root(%Plug.Conn{} = conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: Routes.timelines_path(conn, :home))
    else
      redirect(conn, to: Routes.timelines_path(conn, :local))
    end
  end

  def home(%Plug.Conn{} = conn, params) do
    render_timeline(conn, :home, params)
  end

  def local(%Plug.Conn{} = conn, params) do
    render_timeline(conn, :local, params)
  end

  def federated(%Plug.Conn{} = conn, params) do
    render_timeline(conn, :federated, params)
  end

  def create(%Plug.Conn{} = conn, %{"post" => post_params}) do
    %User{ap_id: ap_id, inbox: inbox} = conn.assigns[:current_user]
    opts = [visibility: :public, webfinger_module: HTTPClient]
    activity = Fedi.Client.post(ap_id, post_params["content"], %{}, opts) |> Jason.encode!()

    inbox = Utils.to_uri(inbox)
    outbox = Utils.base_uri(inbox, String.replace_trailing(inbox.path, "/inbox", "/outbox"))
    app_agent = FediServer.Application.app_agent()
    result = Activities.deliver(inbox, app_agent, activity, outbox)

    conn
    |> put_flash("posted #{inspect(result)}")
    |> redirect(to: Routes.timelines_path(conn, :home))
  end

  defp render_timeline(conn, which, params) do
    opts = APUtils.collection_opts(params, conn)

    case FediServer.Activities.get_timeline(which, opts) do
      {:ok, oc_map} ->
        statuses = Map.get(oc_map, "orderedItems", []) |> List.wrap()
        count = Enum.count(statuses)
        next = Map.get(oc_map, "next")

        title =
          case which do
            :local -> "Local Timeline"
            :federated -> "Federated Timeline"
            _ -> "Home"
          end

        Logger.error("rendering index.html")

        render(conn, "index.html",
          title: title,
          timeline: statuses,
          count: count,
          next: next,
          previous: nil
        )

      {:error, reason} ->
        Logger.error("timeline error #{reason}")
        conn |> put_status(500) |> halt()
    end
  end
end
