import Config
import Dotenvy

[
  ".env",
  "#{config_env()}.env",
  "#{config_env()}.local.env",
  System.get_env()
]
|> Dotenvy.source!()

# :client_id and :client_secret must be obtained from GitHub
# Create a [Github OAuth app](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app)
# from [this page](https://github.com/settings/applications/new)
# Set the app homepage to `http://localhost:4000` and
# `Authorization callback URL` to `http://localhost:4000/oauth/callbacks/github`
# After completing the form, click "Generate a new client secret"
# to obtain your API secret.
# In production add the client id and secret in the file `.env`
# in the project root directory with the keys "GITHUB_CLIENT_ID" and "GITHUB_CLIENT_SECRET"
config :fedi_server, :github,
  client_id: Dotenvy.env!("GITHUB_CLIENT_ID"),
  client_secret: Dotenvy.env!("GITHUB_CLIENT_SECRET")

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/fedi_server start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :fedi_server, FediServerWeb.Endpoint, server: true
end

{default_instance_url, federated_protocol_enabled?} =
  case config_env() do
    :dev -> {"http://localhost:4000", false}
    _ -> {"https://example.com", true}
  end

instance_url = System.get_env("INSTANCE_URL", default_instance_url)

config :fedi, endpoint_url: instance_url <> "/"

config :boruta, Boruta.Oauth, issuer: instance_url

config :fedi_server,
  federated_protocol_enabled?: federated_protocol_enabled?

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :fedi_server, FediServer.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :fedi_server, FediServerWeb.Endpoint,
    url: [host: host, port: port],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :fedi_server, :github,
    client_id: System.fetch_env!("GITHUB_CLIENT_ID"),
    client_secret: System.fetch_env!("GITHUB_CLIENT_SECRET")
end
