defmodule FediServerWeb.OutboxControllerTest do
  use FediServerWeb.ConnCase, async: false

  import FediServer.FixturesHelper

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities

  setup do
    FediServerWeb.MockRequestHelper.setup_mocks(__MODULE__)
  end

  test "GET /users/alyssa/outbox", %{conn: conn} do
    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/outbox")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollection\""
    assert json_body =~ "/users/alyssa/outbox"
  end

  test "GET /users/alyssa/outbox?page=true", %{conn: conn} do
    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/outbox?page=true")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollectionPage\""
    assert json_body =~ "/users/alyssa/outbox?page=true"
  end

  test "GET /users/alyssa/collections/liked", %{conn: conn} do
    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/collections/liked")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollection\""
    assert json_body =~ "/users/alyssa/collections/liked"
  end

  test "GET /users/alyssa/collections/liked?page=true", %{conn: conn} do
    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/collections/liked?page=true")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollectionPage\""
    assert json_body =~ "/users/alyssa/collections/liked?page=true"
  end

  test "outbox MUST accept activities", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://chatty.example/users/ben",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)
  end

  test "outbox MUST accept non activity objects", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "attributedTo" => "https://example.com/users/alyssa",
      "to" => "https://chatty.example/users/ben",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)
  end

  test "outbox MUST remove bto and bcc", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5",
      "to" => "https://chatty.example/users/ben",
      "bcc" => "https://other.example/users/charlie",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://chatty.example/users/ben",
        "bcc" => "https://other.example/users/charlie",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Now fetch activity, its object, and the object id
    assert activity = get_posted_item()
    assert :ok = APUtils.verify_no_hidden_recipients(activity)

    # Also check on the activities delivered to ben and charlie
    requests = Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)

    ["https://chatty.example/users/ben", "https://other.example/users/charlie"]
    |> Enum.each(fn actor_id ->
      case Enum.find(requests, fn {url, _data} -> url == actor_id <> "/inbox" end) do
        nil -> flunk("No payload was delivered to #{actor_id}/inbox")
        {_url, data} -> assert :ok = APUtils.verify_no_hidden_recipients(data, "activity")
      end
    end)
  end

  test "outbox MUST ignore id", %{conn: conn} do
    submitted_id = "https://example.com/users/alyssa/objects/1"

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "id" => submitted_id,
      "attributedTo" => "https://example.com/users/alyssa",
      "to" => "https://chatty.example/users/ben",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Now fetch activity, its object, and the object id
    assert response(conn, 201)
    assert activity = get_posted_item()
    assert object = Utils.get_object(activity)
    assert %URI{} = id = APUtils.to_id(object)
    assert URI.to_string(id) != submitted_id
  end

  test "outbox MUST respond with 201 status", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "attributedTo" => "https://example.com/users/alyssa",
      "to" => "https://chatty.example/users/ben",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)
  end

  test "outbox MUST set location header", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "attributedTo" => "https://example.com/users/alyssa",
      "to" => "https://chatty.example/users/ben",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert [location] = get_resp_header(conn, "location")
    assert location =~ "/users/alyssa/activities/"
  end

  test "outbox create SHOULD merge audience properties", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5",
      "to" => "https://chatty.example/users/ben",
      "bcc" => "https://example.com/users/daria",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://chatty.example/users/ben",
        "cc" => "https://other.example/users/charlie",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)
    assert activity = get_posted_item()
    assert {:ok, act_recipients} = APUtils.get_recipients(activity, as_map: true)

    object = Utils.get_object(activity)
    assert {:ok, obj_recipients} = APUtils.get_recipients(object, as_map: true)

    Enum.each(["to", "cc", "bcc"], fn prop_name ->
      assert {prop_name, Map.get(act_recipients, prop_name)} ==
               {prop_name, Map.get(obj_recipients, prop_name)}
    end)
  end

  test "outbox create SHOULD copy actor to attributedTo", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK5",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)
    assert activity = get_posted_item()
    assert object = Utils.get_object(activity)

    assert Utils.get_iri(object, "attributedTo") |> URI.to_string() ==
             "https://example.com/users/alyssa"
  end

  test "outbox update MUST check authorization (success)", %{conn: conn} do
    {users, _activities, [note1, _note3, _tombstone]} = outbox_fixtures()

    # note1 is owned by alyssa
    note1_id = note1.data["id"]

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Update",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "id" => note1_id,
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://chatty.example/users/ben",
        "content" => "I take it all back."
      }
    }

    %{alyssa: %{user: alyssa}} = users

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)
  end

  test "outbox update MUST check authorization (failure)", %{conn: conn} do
    {users, _activities, [_note1, note3, _tombstone]} = outbox_fixtures()

    # note3 is owned by daria!
    note3_id = note3.data["id"]

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Update",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "id" => note3_id,
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://chatty.example/users/ben",
        "content" => "I take it all back."
      }
    }

    %{alyssa: %{user: alyssa}} = users

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 422)
  end

  test "outbox SHOULD NOT trust submitted content (bad attributedTo in Create)", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com//users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/daria",
        "to" => "https://chatty.example/users/ben",
        "content" => "I take it all back."
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 401)
  end

  test "outbox SHOULD validate content (update)", %{conn: conn} do
    {users, _activities, [note1, _note3, _tombstone]} = outbox_fixtures()

    # note1 is owned by alyssa
    note1_id = note1.data["id"]

    # Changed the type and attributedTo!
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Update",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "id" => note1_id,
        "type" => "Article",
        "attributedTo" => "https://example.com/users/daria",
        "to" => "https://chatty.example/users/ben",
        "content" => "I take it all back."
      }
    }

    %{alyssa: %{user: alyssa}} = users

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 422)
  end

  test "outbox follow SHOULD add followed object", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => "https://example.com/users/alyssa/activities/01GPQ4DCJTWE0TZ2GENB8BZMK8",
      "type" => "Follow",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => "https://chatty.example/users/ben"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    # QUESTION Should a Follow return 202?
    assert response(conn, 201)

    assert %URI{} = following_id = get_posted_item("https://example.com/users/alyssa/following")
    assert URI.to_string(following_id) == "https://chatty.example/users/ben"
  end

  test "outbox add SHOULD add object to target", %{conn: conn} do
    {users, [_create | _], [note | _]} = outbox_fixtures()

    # Using the "featured" collection as the target
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Add",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => note.ap_id,
      "target" => "https://example.com/users/alyssa/collections/featured"
    }

    %{alyssa: %{user: alyssa}} = users

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    assert Utils.to_uri(note.ap_id) ==
             get_posted_item("https://example.com/users/alyssa/collections/featured")
  end

  test "outbox remove SHOULD remove object from target", %{conn: conn} do
    {users, [_create | _], [note | _]} = outbox_fixtures()

    # Using the "featured" collection as the target
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Add",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => note.ap_id,
      "target" => "https://example.com/users/alyssa/collections/featured"
    }

    %{alyssa: %{user: alyssa}} = users

    _ =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    # Now remove it
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Remove",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => note.ap_id,
      "target" => "https://example.com/users/alyssa/collections/featured"
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)
    refute get_posted_item("https://example.com/users/alyssa/collections/featured")
  end

  test "outbox like SHOULD add object to liked", %{conn: conn} do
    {users, [_create | _], [note | _]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Like",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => note.ap_id
    }

    %{alyssa: %{user: alyssa}} = users

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    assert %URI{} =
             object_id = get_posted_item("https://example.com/users/alyssa/collections/liked")

    assert URI.to_string(object_id) == note.ap_id
  end

  test "outbox block SHOULD prevent interaction with actor", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Block",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => "https://chatty.example/users/ben"
    }

    %{alyssa: %{user: alyssa}, ben: %{user: ben, keys: keys_pem}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 401)
  end

  test "outbox block twice is a no-op", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Block",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => "https://chatty.example/users/ben"
    }

    %{alyssa: %{user: alyssa}, ben: %{user: ben, keys: keys_pem}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Do it again
    conn =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 401)
  end

  test "outbox undo MAY be supported (non-normative)", %{conn: conn} do
    # First, follow
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => "https://chatty.example/users/ben"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Then, undo follow
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Undo",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Follow",
        "actor" => "https://example.com/users/alyssa",
        "object" => "https://chatty.example/users/ben"
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    refute get_posted_item("https://example.com/users/alyssa/following")
  end

  test "outbox undo MUST ensure activity and actor are same", %{conn: conn} do
    # First, follow
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "to" => "https://www.w3.org/ns/activitystreams#Public",
      "cc" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => "https://chatty.example/users/ben"
    }

    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Then, undo follow
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Undo",
      "to" => "https://www.w3.org/ns/activitystreams#Public",
      "cc" => "https://example.com/users/daria/followers",
      "actor" => "https://example.com/users/daria",
      "object" => %{
        "type" => "Follow",
        "actor" => "https://example.com/users/alyssa",
        "object" => "https://chatty.example/users/ben"
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(daria)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/daria/outbox", Jason.encode!(activity))

    assert response(conn, 422)
  end

  test "outbox retrieval MUST respond unuathorized with public contents", %{
    conn: conn
  } do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "to" => "https://www.w3.org/ns/activitystreams#Public",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://www.w3.org/ns/activitystreams#Public",
        "content" => "Hello, world!"
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    assert %T.Create{} = get_posted_item("https://example.com/users/alyssa/outbox", "")
  end

  test "outbox retrieval MUST respond with filtered contents (direct recipient)", %{
    conn: conn
  } do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "to" => "https://example.com/users/daria",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://example.com/users/daria",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    assert %T.Create{} =
             get_posted_item(
               "https://example.com/users/alyssa/outbox",
               "https://example.com/users/daria"
             )
  end

  test "outbox retrieval MUST respond with filtered contents (following recipient)",
       %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://example.com/users/alyssa/followers",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{alyssa: %{user: alyssa}, daria: %{user: daria}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Now daria will be one of alyssa's followers
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "to" => "https://example.com/users/daria/followers",
      "actor" => "https://example.com/users/daria",
      "object" => "https://example.com/users/alyssa"
    }

    build_conn()
    |> log_in_user(daria)
    |> Plug.Conn.put_req_header("content-type", "application/activity+json")
    |> post("/users/daria/outbox", Jason.encode!(activity))

    assert %T.Create{} =
             get_posted_item(
               "https://example.com/users/alyssa/outbox",
               "https://example.com/users/daria"
             )
  end

  test "outbox retrieval MUST respond with filtered contents (non-following recipient)",
       %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/alyssa",
        "to" => "https://example.com/users/alyssa/followers",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    refute get_posted_item(
             "https://example.com/users/alyssa/outbox",
             "https://example.com/users/daria"
           )
  end

  test "server security considerations outbox MAY verify content posted by actor (non-normative)",
       %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com//users/daria",
      "object" => %{
        "type" => "Note",
        "attributedTo" => "https://example.com/users/daria",
        "to" => "https://chatty.example/users/ben",
        "content" => "I take it all back."
      }
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 401)
  end

  defp get_posted_item(coll_url \\ "https://example.com/users/alyssa/outbox", filtered_for \\ nil) do
    case get_page(coll_url, filtered_for) do
      {:ok,
       %{
         properties: %{
           "orderedItems" => %P.OrderedItems{values: [%P.OrderedItemsIterator{} = iter | _]}
         }
       } = _outbox_page} ->
        case iter do
          %{member: as_type} when is_struct(as_type) -> as_type
          %{iri: %URI{} = iri} -> iri
          _ -> nil
        end

      _ ->
        nil
    end
  end

  def get_page(coll_url, nil) do
    Utils.to_uri(coll_url) |> Activities.get_collection_unfiltered()
  end

  def get_page(coll_url, viewer_ap_id) when is_binary(viewer_ap_id) do
    viewer_ap_id =
      if Activities.local?(Utils.to_uri(viewer_ap_id)) do
        viewer_ap_id
      else
        nil
      end

    opts = APUtils.collection_opts(%{"page" => "true"}, viewer_ap_id)
    Utils.to_uri(coll_url) |> Activities.get_collection(opts)
  end
end
