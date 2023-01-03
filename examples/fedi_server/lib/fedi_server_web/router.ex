defmodule FediServerWeb.Router do
  use FediServerWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:set_actor)
  end

  scope "/", FediServerWeb do
    pipe_through(:api)

    get("/inbox", InboxController, :get_shared_inbox)
    post("/inbox", InboxController, :post_shared_inbox)
    get("/users/:nickname/inbox", InboxController, :get_inbox)
    post("/users/:nickname/inbox", InboxController, :post_inbox)
    get("/users/:nickname/outbox", OutboxController, :get_outbox)
    post("/users/:nickname/outbox", OutboxController, :post_outbox)
  end

  def set_actor(conn, _opts) do
    actor =
      Fedi.ActivityPub.SideEffectActor.new(
        FediServerWeb.SocialCallbacks,
        c2s: FediServerWeb.SocialCallbacks,
        s2s: FediServerWeb.FederatingCallbacks,
        database: FediServer.Activities
      )

    Plug.Conn.put_private(conn, :actor, actor)
  end
end
