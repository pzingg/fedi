defmodule FediServerWeb.Controllers.Oauth.IntrospectControllerTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Mox

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectResponse
  alias FediServerWeb.Oauth.IntrospectController

  setup :verify_on_exit!

  setup do
    {:ok, conn: build_conn()}
  end

  describe "introspect/2" do
    test "returns an oauth error", %{conn: conn} do
      error = %Error{
        status: :bad_request,
        error: :unknown_error,
        error_description: "Error description"
      }

      Boruta.OauthMock
      |> expect(:introspect, fn conn, module ->
        module.introspect_error(conn, error)
      end)

      conn = IntrospectController.introspect(conn, %{})

      assert json_response(conn, 400) == %{
               "error" => "unknown_error",
               "error_description" => "Error description"
             }
    end

    test "returns an inactive token", %{conn: conn} do
      response = %IntrospectResponse{
        active: false,
        client_id: "client_id",
        username: "username",
        scope: "scope",
        sub: "sub",
        iss: "iss",
        exp: "exp",
        iat: "iat"
      }

      Boruta.OauthMock
      |> expect(:introspect, fn conn, module ->
        module.introspect_success(conn, response)
      end)

      conn = IntrospectController.introspect(conn, %{})

      assert json_response(conn, 200) == %{
               "active" => false
             }
    end

    test "returns an introspected token", %{conn: conn} do
      response = %IntrospectResponse{
        active: true,
        client_id: "client_id",
        username: "username",
        scope: "scope",
        sub: "sub",
        iss: "iss",
        exp: "exp",
        iat: "iat"
      }

      Boruta.OauthMock
      |> expect(:introspect, fn conn, module ->
        module.introspect_success(conn, response)
      end)

      conn = IntrospectController.introspect(conn, %{})

      assert json_response(conn, 200) == %{
               "active" => true,
               "client_id" => "client_id",
               "username" => "username",
               "scope" => "scope",
               "sub" => "sub",
               "iss" => "iss",
               "exp" => "exp",
               "iat" => "iat"
             }
    end
  end
end
