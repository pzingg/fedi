defmodule FediServerWeb.FollowingControllerTest do
  use FediServerWeb.ConnCase

  test "GET /following", %{conn: conn} do
    _ = following_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/following")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollection\""
    assert json_body =~ "\"totalItems\":1"
    assert json_body =~ "\"first\""
  end

  test "GET /following?page=true", %{conn: conn} do
    _ = following_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/following?page=true")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollectionPage\""
    assert json_body =~ "\"orderedItems\":\"https://chatty.example/users/ben\""
  end

  test "GET /followers", %{conn: conn} do
    _ = followers_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/followers")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollection\""
    assert json_body =~ "\"totalItems\":1"
    assert json_body =~ "\"first\""
  end

  test "GET /followers?page=true", %{conn: conn} do
    _ = followers_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/followers?page=true")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollectionPage\""
    assert json_body =~ "\"orderedItems\":\"https://chatty.example/users/ben\""
  end
end
