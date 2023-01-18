defmodule FediServerWeb.OutboxController do
  use FediServerWeb, :controller

  require Logger

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def get_outbox(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)
    handle_get_outbox(conn, actor, params)
  end

  def liked(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    # Filtering on liked activities will be done
    # in Activities.get_outbox
    handle_get_outbox(conn, actor, params)
  end

  def handle_get_outbox(conn, actor, %{"nickname" => nickname} = params) do
    # Pass the connection to the fedi Actor logic
    case Fedi.ActivityPub.Actor.handle_get_outbox(actor, conn, params) do
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
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

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
