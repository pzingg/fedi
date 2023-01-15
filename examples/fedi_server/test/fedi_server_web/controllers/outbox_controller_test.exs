defmodule FediServerWeb.OutboxControllerTest do
  use FediServerWeb.ConnCase, async: false

  import FediServer.FixturesHelper

  require Logger

  alias FediServer.Activities

  setup do
    Tesla.Mock.mock_global(fn
      # When we dereference ben
      %{
        method: :get,
        url: "https://chatty.example/users/ben"
      } ->
        case Path.join(:code.priv_dir(:fedi_server), "ben.json") |> File.read() do
          {:ok, contents} ->
            %Tesla.Env{
              status: 200,
              body: contents,
              headers: [{"content-type", "application/jrd+json; charset=utf-8"}]
            }

          _ ->
            Logger.error("Failed to resolve ben")
            %Tesla.Env{status: 404, body: "Not found"}
        end

      # When we deliver message to ben's inbox
      %{
        method: :post,
        url: "https://chatty.example/users/ben/inbox"
      } ->
        %Tesla.Env{status: 201, body: "Created"}

      %{method: method, url: url} ->
        Logger.error("Unhandled #{method} #{url}")
        %Tesla.Env{status: 404, body: "Not found"}
    end)

    :ok
  end

  test "GET /users/alyssa/outbox", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/outbox")

    assert json_body = response(conn, 200)
    assert json_body =~ "/users/alyssa/outbox?page=true"
  end

  test "POST a Create activity to /users/alyssa/outbox", %{conn: conn} do
    _ = user_fixtures()

    activity = """
    {
      "@context": "https://www.w3.org/ns/activitystreams",
      "type": "Create",
      "id": "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5",
      "to": ["https://www.w3.org/ns/activitystreams#Public", "https://chatty.example/users/ben"],
      "actor": "https://example.com/users/alyssa",
      "object": {
        "type": "Note",
        "attributedTo": "https://example.com/users/alyssa",
        "to": ["https://www.w3.org/ns/activitystreams#Public", "https://chatty.example/users/ben"],
        "content": "Say, did you finish reading that book I lent you?"
      }
    }
    """

    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", activity)

    assert response(conn, 201) == ""
  end

  test "POST a Follow activity to /users/alyssa/outbox", %{conn: conn} do
    _users = user_fixtures(local_only: true)

    activity = """
    {
      "@context": "https://www.w3.org/ns/activitystreams",
      "id": "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK8",
      "type": "Follow",
      "to": ["https://chatty.example/users/ben"],
      "actor": "https://example.com/users/alyssa",
      "object": "https://chatty.example/users/ben"
    }
    """

    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", activity)

    assert response(conn, 201) == ""
  end
end
