defmodule FediServerWeb.ActivitiesControllerTest do
  use FediServerWeb.ConnCase

  test "GET an activity", %{conn: conn} do
    {[activity | _], _objects} = outbox_fixtures()

    %URI{path: path} = URI.parse(activity.ap_id)

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get(path)

    assert response(conn, 200) =~ "/users/alyssa"
  end

  test "GET a missing activity", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/json")
      |> get("/users/alyssa/activities/#{Ecto.ULID.generate()}")

    assert response(conn, 404)
  end
end
