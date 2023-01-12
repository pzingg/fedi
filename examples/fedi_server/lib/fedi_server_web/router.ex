defmodule FediServerWeb.Router do
  use FediServerWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:set_actor)
  end

  pipeline :well_known do
    plug(:accepts, ["json", "jrd+json", "xml", "xrd+xml"])
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

  scope "/.well-known", FediServerWeb do
    pipe_through(:well_known)

    get("/host-meta", WebFinger.WebFingerController, :host_meta)
    get("/webfinger", WebFinger.WebFingerController, :webfinger)
    # get("/nodeinfo", Nodeinfo.NodeinfoController, :schemas)
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
