defmodule FediServerWeb.InboxControllerTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  test "GET /users/alyssa/inbox", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/inbox")

    assert json_body = response(conn, 200)
    assert json_body =~ "/users/alyssa/inbox?page=true"
  end

  test "POST /users/alyssa/inbox", %{conn: conn} do
    _ = user_fixtures()

    activity = """
    {
      "@context": "https://www.w3.org/ns/activitystreams",
      "type": "Create",
      "id": "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to": ["https://example.com/users/alyssa"],
      "actor": "https://chatty.example/users/ben",
      "object": {
        "type": "Note",
        "id": "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to": ["https://example.com/users/alyssa"],
        "attributedTo": "https://chatty.example/users/ben",
        "content": "Say, did you finish reading that book I lent you?"
      }
    }
    """

    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/inbox", activity)

    assert response(conn, 200) =~ "OK"
  end
end
