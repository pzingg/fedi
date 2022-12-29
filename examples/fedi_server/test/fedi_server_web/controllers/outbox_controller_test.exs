defmodule FediServerWeb.OutboxControllerTest do
  use FediServerWeb.ConnCase

  test "GET /server/outbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/server/outbox")

    assert response(conn, 500) =~ "Internal server error"
  end

  test "POST /server/outbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/server/outbox", "NOBODY")

    assert response(conn, 500) =~ "Internal server error"
  end
end
