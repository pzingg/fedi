defmodule FediServerWeb.Openid.UserinfoController do
  @behaviour Boruta.Openid.UserinfoApplication

  use FediServerWeb, :controller

  alias FediServerWeb.OpenidView

  def openid_module, do: Application.get_env(:fedi_server, :openid_module, Boruta.Openid)

  def userinfo(conn, _params) do
    openid_module().userinfo(conn, __MODULE__)
  end

  @impl Boruta.Openid.UserinfoApplication
  def userinfo_fetched(conn, userinfo) do
    conn
    |> put_view(OpenidView)
    |> render("userinfo.json", userinfo: userinfo)
  end

  @impl Boruta.Openid.UserinfoApplication
  def unauthorized(conn, error) do
    conn
    |> put_resp_header(
      "www-authenticate",
      "error=\"#{error.error}\", error_description=\"#{error.error_description}\""
    )
    |> send_resp(:unauthorized, "")
  end
end
