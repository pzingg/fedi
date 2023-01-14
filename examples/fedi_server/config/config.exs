# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :fedi_server,
  user_agent: "(elixir-fedi-0.1.0)"

config :fedi_server,
  ecto_repos: [FediServer.Repo]

# Configures the endpoint
config :fedi_server, FediServerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: FediServerWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: FediServer.PubSub,
  live_view: [signing_salt: "dqsZVvH6"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Akkoma's http_signatures library
config :http_signatures, adapter: Fedi.ActivityPub.HTTPSignatureTransport

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
