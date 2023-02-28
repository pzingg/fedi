defmodule FediServerWeb.Controllers.Openid.JwksControllerTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Mox

  alias FediServerWeb.Openid.JwksController

  setup :verify_on_exit!

  setup do
    {:ok, conn: build_conn()}
  end

  describe "jwks_index/2" do
    test "returns jwks response", %{conn: conn} do
      jwk_keys = jwk_keys_fixture()

      Boruta.OpenidMock
      |> expect(:jwks, fn conn, module ->
        module.jwk_list(conn, jwk_keys)
      end)

      conn = JwksController.jwks_index(conn, %{})

      assert json_response(conn, 200) == %{
               "keys" => jwk_keys
             }
    end
  end

  def jwk_keys_fixture do
    [
      %{
        "kid" => "1",
        "e" => "AQAB",
        "kty" => "RSA",
        "n" =>
          "1PaP_gbXix5itjRCaegvI_B3aFOeoxlwPPLvfLHGA4QfDmVOf8cU8OuZFAYzLArW3PnnwWWy39nVJOx42QRVGCGdUCmV7shDHRsr86-2DlL7pwUa9QyHsTj84fAJn2Fv9h9mqrIvUzAtEYRlGFvjVTGCwzEullpsB0GJafopUTFby8WdSq3dGLJBB1r-Q8QtZnAxxvolhwOmYkBkkidefmm48X7hFXL2cSJm2G7wQyinOey_U8xDZ68mgTakiqS2RtjnFD0dnpBl5CYTe4s6oZKEyFiFNiW4KkR1GVjsKwY9oC2tpyQ0AEUMvk9T9VdIltSIiAvOKlwFzL49cgwZDw"
      },
      %{
        "kid" => "2",
        "e" => "AQAB",
        "kty" => "RSA",
        "n" =>
          "1PaP_gbXix5itjRCaegvI_B3aFOeoxlwPPLvfLHGA4QfDmVOf8cU8OuZFAYzLArW3PnnwWWy39nVJOx42QRVGCGdUCmV7shDHRsr86-2DlL7pwUa9QyHsTj84fAJn2Fv9h9mqrIvUzAtEYRlGFvjVTGCwzEullpsB0GJafopUTFby8WdSq3dGLJBB1r-Q8QtZnAxxvolhwOmYkBkkidefmm48X7hFXL2cSJm2G7wQyinOey_U8xDZ68mgTakiqS2RtjnFD0dnpBl5CYTe4s6oZKEyFiFNiW4KkR1GVjsKwY9oC2tpyQ0AEUMvk9T9VdIltSIiAvOKlwFzL49cgwZDw"
      }
    ]
  end
end
