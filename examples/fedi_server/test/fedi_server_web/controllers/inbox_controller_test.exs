defmodule FediServerWeb.InboxControllerTest do
  use FediServerWeb.ConnCase

  test "GET /users/alyssa/inbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/inbox")

    json = response(conn, 200)
    assert Jason.decode!(json) == FediServerWeb.SocialCallbacks.mock_ordered_collection_json()
  end

  test "POST /users/alyssa/inbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/inbox", "NOBODY")

    assert response(conn, 405) =~ "Method not allowed"
  end
end
