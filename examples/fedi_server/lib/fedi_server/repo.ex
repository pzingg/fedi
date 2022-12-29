defmodule FediServer.Repo do
  use Ecto.Repo,
    otp_app: :fedi_server,
    adapter: Ecto.Adapters.Postgres
end
