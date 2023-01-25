defmodule FediServerWeb.ObjectsControllerTest do
  use FediServerWeb.ConnCase

  alias Fedi.Streams.Utils
  alias FediServer.Activities

  test "server object retrieval MUST respond with ld+json", %{conn: conn} do
    {_users, _activities, [note | _]} = outbox_fixtures()
    %URI{path: path} = Utils.to_uri(note.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/ld+json")
      |> get(path)

    assert response(conn, 200) =~ "/users/alyssa"

    assert Plug.Conn.get_resp_header(conn, "content-type") == [
             "application/ld+json; profile=\"https:www.w3.org/ns/activitystreams\"; charset=utf-8"
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

  test "server object retrieval SHOULD respond private with 403 or 404 status (success - direct)",
       %{conn: conn} do
    {users, _activities, [_note1, note3, _tombstone]} = outbox_fixtures()
    # note3 is owned by daria and addressed to her followers only
    note3_id = note3.data["id"]
    %URI{path: path} = Utils.to_uri(note3_id)

    # Self is always a follower
    %{daria: %{user: daria}} = users

    conn =
      conn
      |> log_in_user(daria)
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> get(path)

    assert response(conn, 200) =~ "/users/daria"
  end

  test "server object retrieval SHOULD respond private with 403 or 404 status (success - follower)",
       %{conn: conn} do
    {users, _activities, [_note1, note3, _tombstone]} = outbox_fixtures()
    # note3 is owned by daria and addressed to her followers only
    note3_id = note3.data["id"]
    %URI{path: path} = Utils.to_uri(note3_id)
    %{alyssa: %{user: alyssa}} = users

    # Follow daria
    Activities.follow("https://example.com/users/alyssa", "https://example.com/users/daria")

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> get(path)

    assert response(conn, 200) =~ "/users/daria"
  end

  test "server object retrieval SHOULD respond private with 403 or 404 status (failure)", %{
    conn: conn
  } do
    {users, _activities, [_note1, note3, _tombstone]} = outbox_fixtures()
    # note3 is owned by daria and addressed to her followers only
    note3_id = note3.data["id"]
    %URI{path: path} = Utils.to_uri(note3_id)

    # Not a follower
    %{alyssa: %{user: alyssa}} = users

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/json")
      |> get(path)

    assert response(conn, 404)
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
