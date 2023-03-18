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
      FediServerWeb.Endpoint,
      # Start a worker by calling: FediServer.Worker.start_link(arg)
      # {FediServer.Worker, arg}
      {FediServer.Oauth.LoginCache, name: :mastodon_login_cache}
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

  def federated_protocol_enabled?() do
    Application.fetch_env!(:fedi_server, :federated_protocol_enabled?)
  end
end
