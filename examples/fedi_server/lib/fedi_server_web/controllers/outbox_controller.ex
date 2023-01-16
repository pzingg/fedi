defmodule FediServerWeb.OutboxController do
  use FediServerWeb, :controller

  require Logger

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def get_outbox(conn, %{"nickname" => nickname} = _params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)
    handle_get_outbox(conn, actor, nickname)
  end

  def liked(conn, %{"nickname" => nickname} = _params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    # Filter on liked activities
    conn = Plug.Conn.assign(conn, :liked, true)
    handle_get_outbox(conn, actor, nickname)
  end

  def handle_get_outbox(conn, actor, nickname) do
    # Pass the connection to the fedi Actor logic
    case Fedi.ActivityPub.Actor.handle_get_outbox(actor, conn) do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("get_outbox #{nickname} state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_json_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("get_outbox #{nickname} error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_json_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end

  def post_outbox(conn, %{"nickname" => nickname} = _params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.Actor.get_actor!(conn)

    # Pass the connection to the fedi Actor logic
    case Fedi.ActivityPub.Actor.handle_post_outbox(actor, conn) do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("post_outbox #{nickname} state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_json_resp(processed_conn, :no_content, "")
        end

      {:error, reason} ->
        Logger.error("post_outbox #{nickname} error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_json_resp(
          conn,
          :internal_server_error,
          "Internal server error"
        )
    end
  end
end
