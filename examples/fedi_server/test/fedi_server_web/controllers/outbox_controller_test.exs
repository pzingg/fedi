defmodule FediServerWeb.OutboxControllerTest do
  use FediServerWeb.ConnCase

  test "GET /server/outbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/server/outbox")

    json = response(conn, 200)
    assert Jason.decode!(json) == FediServerWeb.MyActorCallbacks.mock_ordered_collection_json()
  end

  test "POST /server/outbox", %{conn: conn} do
    activity = """
    {
      "@context": "https://www.w3.org/ns/activitystreams",
      "type": "Create",
      "id": "https://social.example/alyssa/posts/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to": ["https://chatty.example/ben/"],
      "actor": "https://social.example/alyssa/",
      "object": {
        "type": "Note",
        "id": "https://social.example/alyssa/posts/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "attributedTo": "https://social.example/alyssa/",
        "to": ["https://chatty.example/ben/"],
        "content": "Say, did you finish reading that book I lent you?"
      }
    }
    """

    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/server/outbox", activity)

    assert response(conn, 500) =~ "Internal server error"
  end
end
