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

    assert response(conn, 200) =~ "<!-- 2 activities -->"
  end

  test "redirects from home timeline if unauthenticated", %{conn: conn} do
    {_users, _activities, _objects} = outbox_fixtures()

    conn =
      conn
      |> get("/web/timelines/home")

    assert response(conn, 302) =~ "You are being <a href=\"/users/log_in\">redirected</a>."
  end

  test "gets local timeline (alyssa)", %{conn: conn} do
    {users, _activities, _objects} = outbox_fixtures()
    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = users
    _ = Activities.follow(alyssa.ap_id, daria.ap_id)

    conn =
      conn
      |> log_in_user(alyssa)
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "<!-- 2 activities -->"
  end

  test "gets local timeline (public)", %{conn: conn} do
    {_users, _activities, _objects} = outbox_fixtures()

    conn =
      conn
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "<!-- 1 activity -->"
  end

  test "gets federated timeline (alyssa)", %{conn: conn} do
    {users, _activities, _objects} = outbox_fixtures()
    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = users
    _ = Activities.follow(alyssa.ap_id, daria.ap_id)

    conn =
      conn
      |> log_in_user(alyssa)
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "<!-- 2 activities -->"
  end

  test "gets federated timeline (public)", %{conn: conn} do
    {_users, _activities, _objects} = outbox_fixtures()

    conn =
      conn
      |> get("/web/timelines/local")

    assert response(conn, 200) =~ "<!-- 1 activity -->"
  end

  test "gets alyssa's profile and timeline (authenticated as a follower)", %{conn: conn} do
    {users, _activities, _objects} = outbox_fixtures()
    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = users

    Activities.follow(daria.ap_id, alyssa.ap_id)

    conn =
      conn
      |> log_in_user(daria)
      |> get("/@alyssa")

    assert response(conn, 200) =~ "<!-- 1 activity -->"
  end

  test "gets alyssa's profile and timeline (unauthenticated)", %{conn: conn} do
    {_users, _activities, _objects} = outbox_fixtures()

    conn =
      conn
      |> get("/@alyssa")

    assert response(conn, 200) =~ "<!-- 1 activity -->"
  end
end
