defmodule FediServerWeb.TimelinesController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Accounts.User
  alias FediServer.Activities
  alias FediServerWeb.TimelineHelpers

  action_fallback(FediServerWeb.FallbackController)

  # @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def root(%Plug.Conn{} = conn, _params) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: Routes.timelines_path(conn, :home))
      |> halt()
    else
      conn
      |> redirect(to: Routes.timelines_path(conn, :local))
      |> halt()
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
    content = post_params["content"]
    visibility = post_params["visibility"] |> String.to_existing_atom()

    with {:authenticated, %User{ap_id: ap_id, inbox: inbox}} <-
           {:authenticated, conn.assigns[:current_user]},
         {:authenticated, {:ok, context}} <-
           {:authenticated, Fedi.ActivityPub.ActorFacade.get_actor(conn)},
         inbox <-
           Utils.to_uri(inbox),
         outbox_iri <-
           Utils.base_uri(ap_id, String.replace_trailing(inbox.path, "/inbox", "/outbox")),
         context <-
           struct(context, box_iri: outbox_iri),
         opts <-
           [visibility: visibility, webfinger_module: FediServerWeb.WebFinger],
         activity <-
           Fedi.Client.post(ap_id, content, %{}, opts),
         {:ok, _activity_id, object_id, _recipient_count} <-
           Fedi.ActivityPub.Actor.post_activity(context, activity) do
      conn
      |> put_flash(:info, "Posted #{object_id}")
      |> redirect(to: Routes.timelines_path(conn, :home))
      |> halt()
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Post failed: #{reason}")
        |> redirect(to: Routes.timelines_path(conn, :local))
        |> halt()

      {:authenticated, _} ->
        conn
        |> put_flash(:error, "Not allowed to post")
        |> redirect(to: Routes.timelines_path(conn, :local))
        |> halt()
    end
  end

  defp render_timeline(conn, which, params) do
    opts =
      params
      |> Map.put("page", "true")
      |> APUtils.collection_opts(conn)

    case Activities.get_timeline(which, opts) do
      {:ok, activities} ->
        statuses =
          Enum.map(activities, &TimelineHelpers.transform/1)
          |> Enum.reject(&is_nil(&1))

        title =
          case which do
            :local -> "Local Timeline"
            :federated -> "Federated Timeline"
            _ -> "Home"
          end

        render(conn, "index.html",
          title: title,
          timeline: statuses,
          count: Enum.count(statuses),
          max_id: Map.get(params, "max_id"),
          next: TimelineHelpers.next_url(Routes.timelines_url(conn, which), statuses)
        )

      {:error, reason} ->
        Logger.error("timeline error #{reason}")
        # FallbackController will handle it
        {:error, :internal_server_error}
    end
  end
end
