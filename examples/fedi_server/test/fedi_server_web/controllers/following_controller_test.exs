defmodule FediServerWeb.FollowingControllerTest do
  use FediServerWeb.ConnCase

  test "GET /following", %{conn: conn} do
    _ = following_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/following")

    assert response(conn, 200) =~ "\"orderedItems\":\"https://chatty.example/users/ben\""
  end

  test "GET /followers", %{conn: conn} do
    _ = followers_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/followers")

    assert response(conn, 200) =~ "\"orderedItems\":\"https://chatty.example/users/ben\""
  end
end
