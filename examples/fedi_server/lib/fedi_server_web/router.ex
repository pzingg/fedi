defmodule FediServerWeb.Router do
  use FediServerWeb, :router

  # Note: make sure to configure all these types in config.exs!
  pipeline :api do
    plug(:accepts, ["json"])
    plug(:set_actor)
  end

  pipeline :xrd do
    plug(:accepts, ["xml", "xrd+xml"])
  end

  pipeline :jrd do
    plug(:accepts, ["json", "jrd+json"])
  end

  pipeline :webfinger do
    plug(:accepts, ["json", "jrd+json", "xml", "xrd+xml"])
  end

  scope "/", FediServerWeb do
    pipe_through(:api)

    get("/inbox", InboxController, :get_shared_inbox)
    post("/inbox", InboxController, :post_shared_inbox)
    get("/users/:nickname", UsersController, :profile)
    get("/users/:nickname/inbox", InboxController, :get_inbox)
    post("/users/:nickname/inbox", InboxController, :post_inbox)
    get("/users/:nickname/outbox", OutboxController, :get_outbox)
    post("/users/:nickname/outbox", OutboxController, :post_outbox)
    get("/users/:nickname/activities/:ulid", ActivitiesController, :activity)
    get("/users/:nickname/objects/:ulid", ObjectsController, :object)
  end

  scope "/.well-known", FediServerWeb do
    pipe_through(:webfinger)

    get("/webfinger", WellKnownController, :webfinger)
  end

  scope "/.well-known", FediServerWeb do
    pipe_through(:jrd)

    get("/nodeinfo", WellKnownController, :nodeinfo)
  end

  scope "/.well-known", FediServerWeb do
    pipe_through(:xrd)

    get("/host-meta", WellKnownController, :hostmeta)
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
