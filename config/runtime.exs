import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

config :fedi, user_agent: "(elixir-fedi-#{Mix.Project.config()[:version]})"

default_instance_url =
  case config_env() do
    :dev -> "http://localhost:4000"
    _ -> "https://example.com"
  end

instance_url = System.get_env("INSTANCE_URL", default_instance_url)

config :fedi, endpoint_url: instance_url <> "/"
