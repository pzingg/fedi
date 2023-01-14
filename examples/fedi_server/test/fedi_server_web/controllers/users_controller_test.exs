defmodule FediServerWeb.UsersControllerTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  test "GET a user", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa")

    assert response(conn, 200) =~ "/users/alyssa"
  end

  test "GET a missing user", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa")

    assert response(conn, 404)
  end
end
