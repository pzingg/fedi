defmodule FediServerWeb.InboxControllerTest do
  use FediServerWeb.ConnCase

  test "GET /server/inbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/server/inbox")

    json = response(conn, 200)
    assert Jason.decode!(json) == FediServerWeb.MyActorCallbacks.mock_ordered_collection_json()
  end

  test "POST /server/inbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/server/inbox", "NOBODY")

    assert response(conn, 405) =~ "Method not allowed"
  end
end
