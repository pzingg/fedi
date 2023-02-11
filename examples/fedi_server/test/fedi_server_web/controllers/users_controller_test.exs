defmodule FediServerWeb.UsersControllerTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  test "get the user directory (HTML)", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> get("/web/directory")

    assert response(conn, 200) =~ "<p>2 Users</p>"
  end

  test "get a user profile (HTML)", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> get("/web/accounts/alyssa")

    assert response(conn, 200) =~ "<p>Name: Alyssa Activa</p>"
  end

  test "GET a user (JSON)", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa")

    assert response(conn, 200) =~ "/users/alyssa"
  end

  test "GET a missing user (JSON)", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa")

    assert response(conn, 404)
  end
end
