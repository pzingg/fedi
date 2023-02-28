defmodule FediServerWeb.Oauth.TokenController do
  @behaviour Boruta.Oauth.TokenApplication

  use FediServerWeb, :controller

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse
  alias FediServerWeb.OauthView

  def oauth_module, do: Application.get_env(:fedi_server, :oauth_module, Boruta.Oauth)

  def token(%Plug.Conn{} = conn, _params) do
    conn |> oauth_module().token(__MODULE__)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_success(conn, %TokenResponse{} = response) do
    conn
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("cache-control", "no-store")
    |> put_view(OauthView)
    |> render("token.json", response: response)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end
end
