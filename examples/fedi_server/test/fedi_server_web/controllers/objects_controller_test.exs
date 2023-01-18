defmodule FediServerWeb.ObjectsControllerTest do
  use FediServerWeb.ConnCase

  alias Fedi.Streams.Utils

  test "server object retrieval MUST respond with ld+json", %{conn: conn} do
    {_users, _activities, [note | _]} = outbox_fixtures()

    %URI{path: path} = Utils.to_uri(note.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/ld+json")
      |> get(path)

    assert response(conn, 200) =~ "/users/alyssa"

    assert Plug.Conn.get_resp_header(conn, "content-type") == [
             "application/ld+json; charset=utf-8"
           ]
  end

  test "server object retrieval SHOULD respond with activity+json", %{conn: conn} do
    {_users, _activities, [note | _]} = outbox_fixtures()

    %URI{path: path} = Utils.to_uri(note.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get(path)

    assert response(conn, 200) =~ "/users/alyssa"

    assert Plug.Conn.get_resp_header(conn, "content-type") == [
             "application/activity+json; charset=utf-8"
           ]
  end

  test "server object retrieval deleted object SHOULD respond with 410 status", %{conn: conn} do
    {_users, _activities, objects} = outbox_fixtures()
    tombstone = List.last(objects)

    %URI{path: path} = Utils.to_uri(tombstone.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get(path)

    assert response(conn, 410) =~ "\"formerType\":\"Note\""
  end

  test "server object retrieval deleted object SHOULD respond with 404 status", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/objects/#{Ecto.ULID.generate()}")

    assert response(conn, 404)
  end
end
