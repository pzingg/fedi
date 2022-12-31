defmodule FediServerWeb.OutboxControllerTest do
  use FediServerWeb.ConnCase

  test "GET /server/outbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/server/outbox")

    expected = """
    {"@context":"https://www.w3.org/ns/activitystreams","id":"http://example.org/foo?page=1","orderedItems":[{"name":"A Simple Note","type":"Note"},{"name":"Another Simple Note","type":"Note"}],"partOf":"http://example.org/foo","summary":"Page 1 of Sally's notes","type":"OrderedCollectionPage"}
    """

    assert response(conn, 200) == String.trim(expected)
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
