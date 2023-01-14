defmodule FediServerWeb.ObjectsControllerTest do
  use FediServerWeb.ConnCase

  test "GET an object", %{conn: conn} do
    {_activities, [object | _]} = outbox_fixtures()

    %URI{path: path} = URI.parse(object.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get(path)

    assert response(conn, 200) =~ "/users/alyssa"
  end

  test "GET a missing object", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/objects/#{Ecto.ULID.generate()}")

    assert response(conn, 404)
  end
end
