defmodule FediServerWeb.ObjectsControllerTest do
  use FediServerWeb.ConnCase

  test "GET an object", %{conn: conn} do
    {_activities, [note | _]} = outbox_fixtures()

    %URI{path: path} = URI.parse(note.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get(path)

    assert response(conn, 200) =~ "/users/alyssa"
  end

  test "GET a tombstoned object", %{conn: conn} do
    {_activities, [_note, tombstone]} = outbox_fixtures()

    %URI{path: path} = URI.parse(tombstone.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get(path)

    assert response(conn, 410) =~ "\"formerType\":\"Note\""
  end

  test "GET a missing object", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/objects/#{Ecto.ULID.generate()}")

    assert response(conn, 404)
  end
end
