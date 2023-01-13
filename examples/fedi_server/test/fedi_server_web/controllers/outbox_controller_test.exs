defmodule FediServerWeb.OutboxControllerTest do
  use FediServerWeb.ConnCase, async: false

  require Logger

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

      %{method: method, url: url} = other ->
        Logger.error("Unhandled #{method} #{url}")
        %Tesla.Env{status: 404, body: "Not found"}
    end)

    :ok
  end

  test "GET /users/alyssa/outbox", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/outbox")

    json = response(conn, 200)
    assert Jason.decode!(json) == FediServerWeb.CommonCallbacks.mock_ordered_collection_json()
  end

  # FIXME Use Tesla.Mock to resolve remote user https://chatty.example/users/ben
  test "POST /users/alyssa/outbox", %{conn: conn} do
    activity = """
    {
      "@context": "https://www.w3.org/ns/activitystreams",
      "type": "Create",
      "id": "https://example.com/users/alyssa/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to": ["https://chatty.example/users/ben"],
      "actor": "https://example.com/users/alyssa",
      "object": {
        "type": "Note",
        "id": "https://example.com/users/alyssa/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "attributedTo": "https://example.com/users/alyssa",
        "to": ["https://chatty.example/users/ben"],
        "content": "Say, did you finish reading that book I lent you?"
      }
    }
    """

    # Seed local user, so we have her private key
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", activity)

    assert response(conn, 201) == ""
  end
end
