defmodule FediServerWeb.ObjectsController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Accounts.User

  action_fallback(FediServerWeb.FallbackController)

  @doc """
  Ref: [AP Section 6.4](https://www.w3.org/TR/activitypub/#delete-activity-outbox)
  If the deleted object is requested the server SHOULD respond with either
  the HTTP 410 Gone status code if a Tombstone object is presented as the
  response body, otherwise respond with a HTTP 404 Not Found.
  """
  def object(%Plug.Conn{} = conn, %{"nickname" => _nickname, "ulid" => ulid}) do
    opts =
      case conn.assigns[:current_user] do
        %User{ap_id: ap_id} ->
          [visible_to: ap_id]

        _ ->
          []
      end

    format = get_format(conn)

    case FediServer.Activities.repo_get(:objects, ulid, opts) do
      %{data: data} when is_map(data) ->
        status = check_for_tombstone(data)

        cond do
          format in ["html"] ->
            if status == :gone do
              conn |> put_status(:gone) |> halt()
            else
              content = data["content"]

              case FediServer.Content.parse_markdown(content, html: true) do
                {:ok, html, _} ->
                  render(conn, "show.html", html_content: html)

                error ->
                  Logger.error("parse_markdown ERROR #{inspect(error)}")
                  conn |> put_status(:internal_server_error) |> halt()
              end
            end

          true ->
            case Jason.encode(data) do
              {:ok, body} ->
                APUtils.send_json_resp(conn, status, body)

              {:error, reason} ->
                Logger.error("Encoding error #{inspect(reason)}")
                APUtils.send_json_resp(conn, :internal_server_error)
            end
        end

      error_or_nil ->
        cond do
          format in ["html"] ->
            if error_or_nil do
              conn |> put_status(:internal_server_error) |> halt()
            else
              conn |> put_status(:not_found) |> halt()
            end

          true ->
            if error_or_nil do
              APUtils.send_json_resp(conn, :internal_server_error)
            else
              APUtils.send_json_resp(conn, :not_found)
            end
        end
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
