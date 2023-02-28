import Config

# Mock HTTP responses
config :tesla, adapter: Tesla.Mock

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :fedi_server, FediServer.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5433,
  database: "fedi_server_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fedi_server, FediServerWeb.Endpoint,
  # FIXME: "https" is ignored!
  url: [host: "example.com", port: 443, scheme: "https"],
  http: [ip: {127, 0, 0, 1}, port: 4002],
  # https: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6+nWwcs/eTsZkAhTLCV5FiFJOAf3zAZOKUIjFi/J2fPsgvYHO7Vp0kHgJRDeIfd8",
  server: false

# Oauth testing
config :fedi_server, :oauth_module, Boruta.OauthMock
config :fedi_server, :openid_module, Boruta.OpenidMock

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
