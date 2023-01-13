defmodule FediServerWeb.InboxController do
  use FediServerWeb, :controller

  require Logger

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def get_inbox(conn, %{"nickname" => nickname} = params) do
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    case Fedi.ActivityPub.Actor.handle_get_inbox(actor, conn) do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("get_inbox #{nickname} state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_text_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("get_inbox #{nickname} error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_text_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end

  def post_inbox(conn, %{"nickname" => nickname} = params) do
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    case Fedi.ActivityPub.Actor.handle_post_inbox(actor, conn) do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("post_inbox #{nickname} state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_text_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("post_inbox #{nickname} error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_text_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end

  def get_shared_inbox(conn, _params) do
    Fedi.ActivityPub.Utils.send_text_resp(
      conn,
      :forbidden,
      "Forbidden"
    )
  end

  def post_shared_inbox(conn, params) do
    Fedi.ActivityPub.Utils.send_text_resp(
      conn,
      :forbidden,
      "Forbidden"
    )
  end
end
