import Config

config :fedi, endpoint_url: "http://localhost:4000/"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
