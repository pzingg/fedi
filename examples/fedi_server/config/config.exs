# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :fedi,
  user_agent: "(elixir-fedi-server-#{Mix.Project.config()[:version]})",
  endpoint_url: "https://example.com/"

config :fedi_server,
  federated_protocol_enabled?: true,
  ecto_repos: [FediServer.Repo]

# Configures the endpoint
config :fedi_server, FediServerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: FediServerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: FediServer.PubSub,
  live_view: [signing_salt: "dqsZVvH6"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.16.4",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure dart_sass (for .scss files)
config :dart_sass,
  version: "1.54.5",
  default: [
    args: ~w(css/app.scss ../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Akkoma's http_signatures library
config :http_signatures, adapter: FediServer.HTTPClient

# Configure all the "Accept" types we will handle
config :mime, :types, %{
  "text/xml" => ["xml"],
  "application/xml" => ["xml"],
  "application/xrd+xml" => ["xrd+xml"],
  "text/json" => ["xml"],
  "application/json" => ["json"],
  "application/ld+json" => ["json"],
  "application/jrd+json" => ["jrd+json"],
  "application/activity+json" => ["json"]
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
