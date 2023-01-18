defmodule FediServerWeb.OutboxController do
  use FediServerWeb, :controller

  require Logger

  alias Fedi.Streams.Error

  @sent_or_chunked [:sent, :chunked, :upgraded, :file]

  def get_outbox(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    Fedi.ActivityPub.Actor.handle_get_outbox(actor, conn, params)
    |> maybe_send_response(conn, "get_outbox", nickname)
  end

  def liked(conn, %{"nickname" => nickname} = params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    # Filtering on liked activities will be done
    # in Activities.get_outbox
    Fedi.ActivityPub.Actor.handle_get_outbox(actor, conn, params)
    |> maybe_send_response(conn, "liked", nickname)
  end

  def post_outbox(conn, %{"nickname" => nickname} = _params) do
    # Get the Actor struct placed in the connection by the
    # `set_actor/2` plug in router.ex.
    actor = Fedi.ActivityPub.ActorFacade.get_actor!(conn)

    # Pass the connection to the fedi Actor logic
    Fedi.ActivityPub.Actor.handle_post_outbox(actor, conn)
    |> maybe_send_response(conn, "post_outbox", nickname)
  end

  def maybe_send_response(result, conn, label, nickname) do
    case result do
      {:ok, processed_conn} ->
        if actor_state = processed_conn.private[:actor_state] do
          Logger.error("#{label} #{nickname} state #{actor_state}")
        end

        if processed_conn.state in @sent_or_chunked do
          processed_conn
        else
          Fedi.ActivityPub.Utils.send_json_resp(processed_conn, :ok)
        end

      {:error, %Error{} = error} ->
        Fedi.ActivityPub.Utils.send_json_resp(conn, error)

      {:error, reason} ->
        Logger.error("#{label} #{nickname} error #{inspect(reason)}")

        Fedi.ActivityPub.Utils.send_json_resp(conn, :internal_server_error)
    end
  end
end
