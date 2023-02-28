defmodule FediServerWeb.Router do
  use FediServerWeb, :router

  import FediServerWeb.UserAuth

  # Note: no live view stuff
  pipeline :browser do
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_root_layout, {FediServerWeb.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
    plug(:set_actor)
  end

  pipeline :api do
    plug(:put_format, "json")
    plug(:fetch_session)
    plug(:fetch_current_user)
    plug(:set_actor)
  end

  pipeline :authenticated do
    plug(:require_authenticated_user)
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
    plug(:put_format, "html")
  end

  pipeline :accepts_any do
    plug(:accepts, ["html", "json"])
  end

  scope "/.well-known", FediServerWeb do
    pipe_through(:xrd)

    get("/host-meta", WellKnownController, :hostmeta)
  end

  scope "/.well-known", FediServerWeb do
    pipe_through(:jrd)

    get("/nodeinfo", WellKnownController, :nodeinfo)
  end

  scope "/.well-known", FediServerWeb do
    pipe_through(:webfinger)

    get("/webfinger", WellKnownController, :webfinger)
  end

  scope "/nodeinfo", FediServerWeb do
    pipe_through(:jrd)

    get("/:version", WellKnownController, :nodeinfo_version)
  end

  scope "/oauth", FediServerWeb.Oauth do
    pipe_through(:api)

    post("/revoke", RevokeController, :revoke)
    post("/token", TokenController, :token)
    post("/introspect", IntrospectController, :introspect)
  end

  scope "/oauth", FediServerWeb.Oauth do
    pipe_through([:browser, :fetch_current_user])

    get("/authorize", AuthorizeController, :authorize)
  end

  scope "/openid", FediServerWeb.Openid do
    pipe_through(:api)

    get("/userinfo", UserinfoController, :userinfo)
    post("/userinfo", UserinfoController, :userinfo)
    get("/jwks", JwksController, :jwks_index)
  end

  scope "/web", FediServerWeb do
    pipe_through([:accepts_html, :browser, :authenticated])

    get("/timelines/home", TimelinesController, :home)
    post("/timelines/home", TimelinesController, :create)
  end

  scope "/web", FediServerWeb do
    pipe_through([:accepts_html, :browser])

    get("/directory", UsersController, :index)
    get("/accounts/:nickname", UsersController, :show)

    get("/statuses/:ulid", ObjectsController, :show)

    get("/timelines/local", TimelinesController, :local)
    get("/timelines/federated", TimelinesController, :federated)
  end

  scope "/", FediServerWeb do
    pipe_through([:accepts_html, :browser])

    get("/users/register", UserRegistrationController, :new)
    post("/users/register", UserRegistrationController, :create)
    get("/users/log_in", UserSessionController, :new)
    post("/users/log_in", UserSessionController, :create)
    delete("/users/log_out", UserSessionController, :delete)
  end

  scope "/", FediServerWeb do
    pipe_through([:accepts_any, :browser])
    get("/users/:nickname", UsersController, :show)
    get("/users/:nickname/objects/:ulid", ObjectsController, :show)
    # get("/users/:nickname/objects/:ulid/reblogs", ObjectsController, :reblogs)
    # get("/users/:nickname/objects/:ulid/favourites", ObjectsController, :favourites)

    get("/@:nickname", UsersController, :show)
    get("/@:nickname/:ulid", ObjectsController, :show)
    # get("/@:nickname/:ulid/reblogs", ObjectsController, :reblogs)
    # get("/@:nickname/:ulid/favourites", ObjectsController, :favourites)

    # get("/tags/:tag", HashtagsController, :show)

    get("/", TimelinesController, :root)
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

  @doc """
  This plug attaches a configured `Fedi.ActivityPub.SideEffectActor`
  struct to the connection. Controllers can extract the Actor by

  """
  def set_actor(conn, _opts) do
    s2s_module =
      if FediServer.Application.federated_protocol_enabled?() do
        FediServerWeb.FederatingCallbacks
      else
        nil
      end

    actor =
      Fedi.ActivityPub.SideEffectActor.new(
        FediServerWeb.SocialCallbacks,
        FediServer.Activities,
        c2s: FediServerWeb.SocialCallbacks,
        s2s: s2s_module,
        current_user: conn.assigns[:current_user]
      )

    Plug.Conn.put_private(conn, :actor, actor)
  end
end
