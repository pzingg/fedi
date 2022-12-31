defmodule FediServerWeb.Router do
  use FediServerWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:set_actor)
  end

  scope "/server", FediServerWeb do
    pipe_through(:api)

    get("/inbox", InboxController, :get_inbox)
    post("/inbox", InboxController, :post_inbox)
    get("/outbox", OutboxController, :get_outbox)
    post("/outbox", OutboxController, :post_outbox)
  end

  def set_actor(conn, _opts) do
    actor =
      Fedi.ActivityPub.SideEffectActor.new(
        FediServerWeb.MyActorCallbacks,
        c2s: FediServerWeb.MyActorCallbacks,
        database: FediServer.Activities
      )

    Plug.Conn.put_private(conn, :actor, actor)
  end
end
