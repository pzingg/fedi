defmodule FediServerWeb.ObjectsController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Accounts.User
  alias FediServer.Activities
  alias FediServer.Activities.Object

  action_fallback(FediServerWeb.FallbackController)

  def show(%Plug.Conn{} = conn, %{"nickname" => _nickname, "ulid" => ulid}) do
    opts =
      case conn.assigns[:current_user] do
        %User{ap_id: ap_id} ->
          [visible_to: ap_id]

        _ ->
          []
      end

    FediServer.Activities.repo_get(:objects, ulid, opts)
    |> render_object(conn)
  end

  def show(%Plug.Conn{} = conn, _params) do
    APUtils.send_json_resp(conn, :not_found)
  end

  # Ref: [AP Section 6.4](https://www.w3.org/TR/activitypub/#delete-activity-outbox)
  # If the deleted object is requested the server SHOULD respond with either
  # the HTTP 410 Gone status code if a Tombstone object is presented as the
  # response body, otherwise respond with a HTTP 404 Not Found.
  defp render_object(%Object{data: data} = object, %Plug.Conn{} = conn) when is_map(data) do
    status = check_for_tombstone(data)

    if Enum.member?(["html"], get_format(conn)) do
      render_object_html(object, conn, status)
    else
      render_object_json(object, conn, status)
    end
  end

  defp render_object(error_or_nil, %Plug.Conn{} = conn) do
    status = if error_or_nil, do: :internal_server_error, else: :not_found

    if get_format(conn) == "html" do
      # FallbackController will handle it
      {:error, status}
    else
      APUtils.send_json_resp(conn, status)
    end
  end

  defp render_object_html(%Object{id: ulid, actor: actor_id, data: object_data}, conn, status) do
    if status == :gone do
      # FallbackController will handle it
      {:error, :gone}
    else
      actor_iri = Utils.to_uri(actor_id)

      case Activities.ensure_user(actor_iri) do
        {:ok, %User{data: actor_data}} ->
          activity =
            FediServerWeb.TimelineHelpers.transform(
              %{
                domain: :objects,
                id: ulid,
                object: object_data,
                actor: actor_data
              },
              nil
            )

          if activity do
            render(conn, "show.html", activity: activity)
          else
            # FallbackController will handle it
            {:error, :internal_server_error}
          end

        {:error, reason} ->
          Logger.error("Could not get user #{actor_iri}: #{reason}")
          # FallbackController will handle it
          {:error, :internal_server_error}
      end
    end
  end

  defp render_object_json(%Object{data: data}, conn, status) do
    case Jason.encode(data) do
      {:ok, body} ->
        APUtils.send_json_resp(conn, status, body)

      {:error, reason} ->
        Logger.error("Encoding error #{inspect(reason)}")
        APUtils.send_json_resp(conn, :internal_server_error)
    end
  end

  defp check_for_tombstone(data) do
    if data["type"] == "Tombstone" do
      :gone
    else
      :ok
    end
  end
end
