defmodule FediServerWeb.TimelinesController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils

  action_fallback(FediServerWeb.FallbackController)

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def home(%Plug.Conn{} = conn, params) do
    if conn.state in @sent_or_chunked do
      conn
    else
      render_timeline(conn, :home, params)
    end
  end

  def local(%Plug.Conn{} = conn, params) do
    render_timeline(conn, :local, params)
  end

  def federated(%Plug.Conn{} = conn, params) do
    render_timeline(conn, :federated, params)
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
