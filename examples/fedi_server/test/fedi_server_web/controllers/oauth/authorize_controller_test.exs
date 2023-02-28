defmodule FediServerWeb.Controllers.Oauth.AuthorizeControllerTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Phoenix.ConnTest

  import Mox

  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias FediServerWeb.Oauth.AuthorizeController

  setup :verify_on_exit!

  setup do
    conn =
      %{build_conn() | query_params: %{}}
      |> init_test_session(%{})

    {:ok, conn: conn}
  end

  defmodule User do
    defstruct id: 1, email: "test@test.test"
  end

  describe "authorize/2" do
    test "redirects to user login without current_user", %{conn: conn} do
      assert_authorize_redirected_to_login(conn)
    end

    test "returns an error page", %{conn: conn} do
      current_user = %User{}
      conn = assign(conn, :current_user, current_user)

      error = %Error{
        status: :bad_request,
        error: :unknown_error,
        error_description: "Error description"
      }

      Boruta.OauthMock
      |> expect(:authorize, fn conn, _resource_owner, module ->
        module.authorize_error(conn, error)
      end)

      conn = AuthorizeController.authorize(conn, %{})

      assert html_response(conn, 400) =~ ~r/Error description/
    end

    test "returns an error in fragment", %{conn: conn} do
      current_user = %User{}
      conn = assign(conn, :current_user, current_user)

      error = %Error{
        status: :bad_request,
        error: :unknown_error,
        error_description: "Error description",
        format: :fragment,
        redirect_uri: "http://redirect.uri"
      }

      Boruta.OauthMock
      |> expect(:authorize, fn conn, _resource_owner, module ->
        module.authorize_error(conn, error)
      end)

      conn = AuthorizeController.authorize(conn, %{})

      assert redirected_to(conn) ==
               "http://redirect.uri#error=unknown_error&error_description=Error+description"
    end

    test "returns an error in query", %{conn: conn} do
      current_user = %User{}
      conn = assign(conn, :current_user, current_user)

      error = %Error{
        status: :bad_request,
        error: :unknown_error,
        error_description: "Error description",
        format: :query,
        redirect_uri: "http://redirect.uri"
      }

      Boruta.OauthMock
      |> expect(:authorize, fn conn, _resource_owner, module ->
        module.authorize_error(conn, error)
      end)

      conn = AuthorizeController.authorize(conn, %{})

      assert redirected_to(conn) ==
               "http://redirect.uri?error=unknown_error&error_description=Error+description"
    end

    test "redirects with an access_token", %{conn: conn} do
      current_user = %User{}
      conn = assign(conn, :current_user, current_user)

      response = %AuthorizeResponse{
        type: :token,
        redirect_uri: "http://redirect.uri",
        access_token: "access_token",
        expires_in: 10
      }

      Boruta.OauthMock
      |> expect(:authorize, fn conn, _resource_owner, module ->
        module.authorize_success(conn, response)
      end)

      conn = AuthorizeController.authorize(conn, %{})

      assert redirected_to(conn) ==
               "http://redirect.uri#access_token=access_token&expires_in=10"
    end

    test "redirects with an access_token and a state", %{conn: conn} do
      current_user = %User{}
      conn = assign(conn, :current_user, current_user)

      response = %AuthorizeResponse{
        type: :token,
        redirect_uri: "http://redirect.uri",
        access_token: "access_token",
        expires_in: 10,
        state: "state"
      }

      Boruta.OauthMock
      |> expect(:authorize, fn conn, _resource_owner, module ->
        module.authorize_success(conn, response)
      end)

      conn = AuthorizeController.authorize(conn, %{})

      assert redirected_to(conn) ==
               "http://redirect.uri#access_token=access_token&expires_in=10&state=state"
    end

    test "redirects with an code", %{conn: conn} do
      current_user = %User{}
      conn = assign(conn, :current_user, current_user)

      response = %AuthorizeResponse{
        type: :code,
        redirect_uri: "http://redirect.uri",
        code: "code"
      }

      Boruta.OauthMock
      |> expect(:authorize, fn conn, _resource_owner, module ->
        module.authorize_success(conn, response)
      end)

      conn = AuthorizeController.authorize(conn, %{})

      assert redirected_to(conn) ==
               "http://redirect.uri?code=code"
    end

    test "redirects with an code and a state", %{conn: conn} do
      current_user = %User{}
      conn = assign(conn, :current_user, current_user)

      response = %AuthorizeResponse{
        type: :code,
        redirect_uri: "http://redirect.uri",
        code: "code",
        state: "state"
      }

      Boruta.OauthMock
      |> expect(:authorize, fn conn, _resource_owner, module ->
        module.authorize_success(conn, response)
      end)

      conn = AuthorizeController.authorize(conn, %{})

      assert redirected_to(conn) ==
               "http://redirect.uri?code=code&state=state"
    end
  end

  defp assert_authorize_redirected_to_login(conn) do
    # assert_raise RuntimeError,
    #   """
    #   Here occurs the login process. After login, user may be redirected to
    #   get_session(conn, :user_return_to)
    #   """,
    #   fn -> AuthorizeController.authorize(conn, %{}) end

    conn = AuthorizeController.authorize(conn, %{})
    assert redirected_to(conn) == "/users/log_in"
  end
end
