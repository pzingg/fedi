defmodule FediServerWeb.Openid.JwksController do
  @behaviour Boruta.Openid.JwksApplication

  use FediServerWeb, :controller

  alias FediServerWeb.OpenidView

  def openid_module, do: Application.get_env(:fedi_server, :openid_module, Boruta.Openid)

  def jwks_index(conn, _params) do
    openid_module().jwks(conn, __MODULE__)
  end

  @impl Boruta.Openid.JwksApplication
  def jwk_list(conn, jwk_keys) do
    conn
    |> put_view(OpenidView)
    |> render("jwks.json", jwk_keys: jwk_keys)
  end
end
