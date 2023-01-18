defmodule FediServerWeb.Router do
  use FediServerWeb, :router

  import FediServerWeb.UserAuth

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:fetch_current_user)
    plug(:set_actor)
  end

  # Note: make sure to configure all these types in config.exs!
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
    get("/users/:nickname/liked", OutboxController, :liked)
    get("/users/:nickname/following", FollowingController, :following)
    get("/users/:nickname/followers", FollowingController, :followers)
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

  scope "/nodeinfo", FediServerWeb do
    pipe_through(:jrd)

    get("/:version", WellKnownController, :nodeinfo_version)
  end

  scope "/.well-known", FediServerWeb do
    pipe_through(:xrd)

    get("/host-meta", WellKnownController, :hostmeta)
  end

  @doc """
  This plug attaches a configured `Fedi.ActivityPub.SideEffectActor`
  struct to the connection. Controllers can extract the Actor by

  """
  def set_actor(conn, _opts) do
    actor =
      Fedi.ActivityPub.SideEffectActor.new(
        FediServerWeb.SocialCallbacks,
        FediServer.Activities,
        c2s: FediServerWeb.SocialCallbacks,
        s2s: FediServerWeb.FederatingCallbacks,
        current_user: conn.assigns[:current_user]
      )

    Plug.Conn.put_private(conn, :actor, actor)
  end
end
