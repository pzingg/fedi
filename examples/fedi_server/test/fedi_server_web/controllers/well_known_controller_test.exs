defmodule FediServerWeb.WellKnownControllerTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  test "GET /.well-known/nodeinfo", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/.well-known/nodeinfo")

    assert response(conn, 200) =~ "https://example.com/nodeinfo/2.0"
  end

  test "GET /nodeinfo/2.0", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/nodeinfo/2.0")

    assert response(conn, 200) =~ "openRegistrations"
  end

  test "GET /nodeinfo/2.1", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/nodeinfo/2.1")

    assert response(conn, 400) =~ "2.0"
  end

  test "GET /.well-known/host-meta", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "text/xml")
      |> get("/.well-known/host-meta")

    assert response(conn, 200) =~ "/.well-known/webfinger?resource={uri}"
  end

  test "GET json /.well-known/webfinger", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/.well-known/webfinger?resource=acct:alyssa@example.com")

    assert response(conn, 200) =~ "\"aliases\":[\"https://example.com/users/alyssa\"]"
  end

  test "GET xml /.well-known/webfinger", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "text/xml")
      |> get("/.well-known/webfinger?resource=acct:alyssa@example.com")

    assert response(conn, 200) =~ "<Alias>https://example.com/users/alyssa</Alias>"
  end

  test "GET /.well-known/webfinger with a missing resource", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/.well-known/webfinger?resource=acct:alyssa@example.com")

    assert response(conn, 404)
  end
end
