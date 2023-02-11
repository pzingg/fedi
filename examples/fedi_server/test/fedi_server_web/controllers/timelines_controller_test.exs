defmodule FediServerWeb.TimelinesControllerTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  alias FediServer.Activities

  setup do
    FediServerWeb.MockRequestHelper.setup_mocks(__MODULE__)
  end

  test "gets home timeline (alyssa)", %{conn: conn} do
    {users, _activities, _objects} = outbox_fixtures()
    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = users
    _ = Activities.follow(alyssa.ap_id, daria.ap_id)

    conn =
      conn
      |> log_in_user(alyssa)
      |> get("/web/timelines/home")

    assert response(conn, 200) =~ "4 Activities"
  end

  test "does not fetch home timeline if unauthenticated", %{conn: conn} do
    {_users, _activities, _objects} = outbox_fixtures()

    conn =
      conn
      |> get("/web/timelines/home")

    assert response(conn, 401)
  end

  test "gets local timeline (alyssa)", %{conn: conn} do
    {users, _activities, _objects} = outbox_fixtures()
    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = users
    _ = Activities.follow(alyssa.ap_id, daria.ap_id)

    conn =
      conn
      |> log_in_user(alyssa)
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "4 Activities"
  end

  test "gets local timeline (public)", %{conn: conn} do
    {_users, _activities, _objects} = outbox_fixtures()

    conn =
      conn
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "3 Activities"
  end

  test "gets federated timeline (alyssa)", %{conn: conn} do
    {users, _activities, _objects} = outbox_fixtures()
    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = users
    _ = Activities.follow(alyssa.ap_id, daria.ap_id)

    conn =
      conn
      |> log_in_user(alyssa)
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "4 Activities"
  end

  test "gets federated timeline (public)", %{conn: conn} do
    {_users, _activities, _objects} = outbox_fixtures()

    conn =
      conn
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "3 Activities"
  end
end
