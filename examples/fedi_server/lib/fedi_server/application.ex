defmodule FediServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      FediServer.Repo,
      # Start the Telemetry supervisor
      FediServerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: FediServer.PubSub},
      # Start the Endpoint (http/https)
      FediServerWeb.Endpoint
      # Start a worker by calling: FediServer.Worker.start_link(arg)
      # {FediServer.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FediServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FediServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def app_agent() do
    Application.get_env(:fedi_server, :user_agent, "(elixir-fedi-server-0.1.0)")
  end
end
