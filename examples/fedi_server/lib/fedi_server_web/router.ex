defmodule FediServerWeb.Router do
  use FediServerWeb, :router

  import FediServerWeb.UserAuth

  pipeline :authenticated do
    plug(:require_authenticated_user)
  end

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

  pipeline :accepts_html do
    plug(:accepts, ["html"])
  end

  pipeline :accepts_any do
    plug(:accepts, ["json", "html"])
  end

  # Note: no live view stuff, no flash
  pipeline :browser do
    plug(:fetch_session)
    plug(:put_root_layout, {FediServerWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
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
    get("/users/:nickname/collections/liked", OutboxController, :liked)
    get("/users/:nickname/following", FollowingController, :following)
    get("/users/:nickname/followers", FollowingController, :followers)
    get("/users/:nickname/activities/:ulid", ActivitiesController, :activity)
  end

  scope "/", FediServerWeb do
    pipe_through([:accepts_any, :browser])

    get("/users/:nickname", UsersController, :show)
    get("/users/:nickname/objects/:ulid", ObjectsController, :object)
  end

  scope "/web", FediServerWeb do
    pipe_through([:accepts_html, :browser])

    get("/directory", UsersController, :index)
    get("/accounts/:nickname", UsersController, :show)
    get("/statuses/:ulid", ObjectsController, :status)
    get("/timelines/local", TimelinesController, :local)
    get("/timelines/federated", TimelinesController, :federated)
  end

  scope "/web", FediServerWeb do
    pipe_through([:accepts_html, :browser, :authenticated])

    get("/timelines/home", TimelinesController, :home)
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
