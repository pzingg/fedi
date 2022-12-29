defmodule FediServerWeb.InboxController do
  use FediServerWeb, :controller

  require Logger

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def get_inbox(conn, _params) do
    actor = conn.private[:actor]

    case Fedi.ActivityPub.Actor.get_inbox(actor, conn) do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("get_inbox state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_text_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("get_inbox error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_text_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end

  def post_inbox(conn, _params) do
    actor = conn.private[:actor]

    case Fedi.ActivityPub.Actor.post_inbox(actor, conn, "http") do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("post_inbox state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_text_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("post_inbox error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_text_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end
end
