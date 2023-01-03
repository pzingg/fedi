defmodule FediServerWeb.OutboxController do
  use FediServerWeb, :controller

  require Logger

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def get_outbox(conn, %{"nickname" => nickname} = params) do
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    case Fedi.ActivityPub.Actor.handle_get_outbox(actor, conn) do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("get_outbox #{nickname} state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_text_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("get_outbox #{nickname} error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_text_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end

  def post_outbox(conn, %{"nickname" => nickname} = params) do
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    case Fedi.ActivityPub.Actor.handle_post_outbox(actor, conn, Atom.to_string(conn.scheme)) do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("post_outbox #{nickname} state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_text_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("post_outbox #{nickname} error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_text_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end
end
