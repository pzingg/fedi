defmodule FediServerWeb.InboxControllerTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities
  alias FediServerWeb.MockRequestHelper

  setup do
    MockRequestHelper.setup_mocks(__MODULE__)
  end

  test "inbox accept MUST deduplicate", %{conn: conn} do
    # Duplication can occur if an activity is addressed both to an
    # actor's followers, and a specific actor who also follows the
    # recipient actor, and the server has failed to de-duplicate
    # the recipients list.
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => ["https://chatty.example/users/ben/followers", "https://example.com/users/alyssa"],
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    body = Jason.encode!(activity)

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    # Send it twice, as if ben's server didn't deduplicate
    conn = sign_and_send(conn, "/users/alyssa/inbox", body, ben, keys_pem)
    assert response(conn, 200)
    assert count_inbox_items() == 1

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", body, ben, keys_pem)

    # No error, but nothing was done
    assert response(conn, 200)
    assert count_inbox_items() == 1
  end

  test "inbox accept MUST special forward", %{conn: conn} do
    # When Activities are received in the inbox, the server needs to forward
    # these to recipients that the origin was unable to deliver them to.
    # To do this, the server MUST target and deliver to the values of to,
    # cc, and/or audience if and only if all of the following are true:
    #
    # - This is the first time the server has seen this Activity.
    # - The values of to, cc, and/or audience contain a Collection owned by the server.
    # - The values of inReplyTo, object, target and/or tag are objects
    #   owned by the server. The server SHOULD recurse through these values
    #   to look for linked objects owned by the server, and SHOULD set a
    #   maximum limit for recursion (ie. the point at which the thread is so
    #   deep the recipients followers may not mind if they are no longer
    #   getting updates that don't directly involve the recipient).
    #   The server MUST only target the values of to, cc, and/or audience
    #   on the original object being forwarded, and not pick up any new
    #   addressees whilst recursing through the linked objects (in case these
    #   addressees were purposefully amended by or via the client).
    {users, _activities, [note1 | _objects]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa/followers",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa/followers",
        "inReplyTo" => note1.ap_id,
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    # Add daria to alyssa's followers
    Activities.follow("https://example.com/users/daria", "https://example.com/users/alyssa")

    %{ben: %{user: ben, keys: keys_pem}} = users
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)
    assert response(conn, 200)

    # Get the payload that was delivered to daria
    deliveries = Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
    assert Enum.count(deliveries) == 1
    assert {"https://example.com/users/daria/inbox", %{json: payload}} = List.first(deliveries)

    assert is_map(payload)
    assert payload["type"] == "Create"

    assert payload["object"]["id"] ==
             "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19"
  end

  test "inbox accept create MAY be supported (non-normative)", %{conn: conn} do
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

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"
  end

  test "inbox accept delete SHOULD remove object", %{conn: conn} do
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

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    _conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Delete",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c922faf",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19"
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    object_id =
      Utils.to_uri(
        "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19"
      )

    assert {:error, "Not found"} = Activities.get_object_data(:objects, object_id)
  end

  test "inbox accept update MUST be authorized (success)", %{conn: conn} do
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

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Update",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d5",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "Yep, all finished"
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"
  end

  test "inbox accept update MUST be authorized (failure)", %{conn: conn} do
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

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Update",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d5",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/charlie",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "Yep, all finished"
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 401)
  end

  test "inbox accept update SHOULD completely replace activity", %{conn: conn} do
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

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    _conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Update",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c922faf",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "That book I lent you wasn't worth reading."
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    object_id =
      Utils.to_uri(
        "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19"
      )

    assert {:ok, m} = Activities.get_object_data(:objects, object_id)
    assert String.contains?(m["content"], "wasn't worth reading")
  end

  test "inbox accept SHOULD NOT trust unverified content (success)", %{conn: conn} do
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

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"
  end

  test "inbox accept SHOULD NOT trust unverified content (failure)", %{conn: conn} do
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
      conn
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/inbox", activity)

    assert response(conn, 401)
  end

  test "inbox accept follow SHOULD add actor to users followers", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => "https://example.com/users/alyssa"
    }

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    assert {:ok, %{properties: %{"orderedItems" => followers}}} =
             MockRequestHelper.get_page("https://example.com/users/alyssa/followers")

    ben_iri = Utils.to_uri("https://chatty.example/users/ben")
    assert APUtils.get_ids(followers) == {:ok, [ben_iri]}
  end

  test "inbox accept follow SHOULD generate accept or reject", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => "https://example.com/users/alyssa"
    }

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    recipients = Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
    assert Enum.count(recipients) == 1
    {url, %{json: body}} = List.first(recipients)
    assert url == "https://chatty.example/users/ben/inbox"
    assert body["type"] == "Accept"
  end

  test "inbox accept accept SHOULD add actor to users following", %{conn: conn} do
    %{alyssa: %{user: alyssa}, ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    follow = follow_ben_request(alyssa)

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Accept",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => follow
    }

    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    assert {:ok, %{properties: %{"orderedItems" => following}}} =
             MockRequestHelper.get_page("https://example.com/users/alyssa/following")

    ben_iri = Utils.to_uri("https://chatty.example/users/ben")
    assert APUtils.get_ids(following) == {:ok, [ben_iri]}
  end

  test "inbox accept reject MUST NOT add actor to users following", %{conn: conn} do
    %{alyssa: %{user: alyssa}, ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    follow = follow_ben_request(alyssa)

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Reject",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => follow
    }

    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    assert {:ok, %{properties: %{"orderedItems" => %P.OrderedItems{values: values}}}} =
             MockRequestHelper.get_page("https://example.com/users/alyssa/following")

    assert values == []
  end

  test "inbox accept add SHOULD add to collection (success)", %{conn: conn} do
    {users, _activities, [note | _]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Add",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => note.ap_id,
      "target" => "https://example.com/users/alyssa/collections/featured"
    }

    %{ben: %{user: ben, keys: keys_pem}} = users
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    assert {:ok, %{properties: %{"orderedItems" => %P.OrderedItems{values: values}}}} =
             MockRequestHelper.get_page("https://example.com/users/alyssa/collections/featured")

    assert [%P.OrderedItemsIterator{alias: "", iri: %URI{} = object_iri}] = values
    assert URI.to_string(object_iri) == note.ap_id
  end

  test "inbox accept add SHOULD add to collection (failure target not owned)", %{conn: conn} do
    {users, _activities, [note | _]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Add",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => note.ap_id,
      "target" => "https://chatty.example/users/ben/collections/featured"
    }

    %{ben: %{user: ben, keys: keys_pem}} = users
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 422)
  end

  test "inbox accept remove SHOULD remove from collection (success)", %{conn: conn} do
    {users, _activities, [note | _]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Add",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => note.ap_id,
      "target" => "https://example.com/users/alyssa/collections/featured"
    }

    %{ben: %{user: ben, keys: keys_pem}} = users
    _conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Remove",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d4",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => note.ap_id,
      "target" => "https://example.com/users/alyssa/collections/featured"
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    assert {:ok, %{properties: %{"orderedItems" => %P.OrderedItems{values: []}}}} =
             MockRequestHelper.get_page("https://example.com/users/alyssa/collections/featured")
  end

  test "inbox accept remove SHOULD remove from collection (failure target not owned)", %{
    conn: conn
  } do
    {users, _activities, [note | _]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Remove",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d4",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => note.ap_id,
      "target" => "https://chatty.example/users/ben/collections/featured"
    }

    %{ben: %{user: ben, keys: keys_pem}} = users
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 422)
  end

  test "inbox accept like SHOULD indicate like performed", %{conn: conn} do
    {users, _activities, [note | _]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Like",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => note.ap_id
    }

    %{ben: %{user: ben, keys: keys_pem}} = users
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    # Now check likes collection
    assert {:ok, %{properties: %{"orderedItems" => %P.OrderedItems{values: values}}}} =
             MockRequestHelper.get_page(note.ap_id <> "/likes")

    assert [%P.OrderedItemsIterator{alias: "", member: person}] = values
    assert APUtils.get_id(person) |> URI.to_string() == "https://chatty.example/users/ben"
  end

  test "inbox accept announce SHOULD add to shares collection", %{conn: conn} do
    {users, _activities, [note | _]} = outbox_fixtures()

    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Announce",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => note.ap_id
    }

    %{ben: %{user: ben, keys: keys_pem}} = users
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    # Now check shares collection
    assert {:ok, %{properties: %{"orderedItems" => %P.OrderedItems{values: values}}}} =
             MockRequestHelper.get_page(note.ap_id <> "/shares")

    assert [%P.OrderedItemsIterator{alias: "", member: person}] = values
    assert APUtils.get_id(person) |> URI.to_string() == "https://chatty.example/users/ben"
  end

  test "inbox accept MAY undo federated (non-normative)", %{conn: conn} do
    # First, follow
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => "https://example.com/users/alyssa"
    }

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    # Then, undo follow
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Undo",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d5",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Follow",
        "actor" => "https://chatty.example/users/ben",
        "object" => "https://example.com/users/alyssa"
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200) =~ "OK"

    assert {:ok, %{properties: %{"orderedItems" => %P.OrderedItems{alias: "", values: []}}}} =
             MockRequestHelper.get_page("https://example.com/users/alyssa/followers")
  end

  test "inbox accept SHOULD validate content", %{conn: conn} do
    # TODO Mock that the "deadbeef" object is not fetchable
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "type" => "Note",
        "id" => "https://chatty.example/users/ben/statuses/deadbeef-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/ben",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 200)

    # Changed the type and attributedTo!
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Update",
      "id" => "https://chatty.example/users/ben/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d5",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/ben",
      "object" => %{
        "id" => "https://chatty.example/users/ben/statuses/deadbeef-b53a-4c4c-a95c-94a6abf45a19",
        "type" => "Article",
        "attributedTo" => "https://example.com/users/daria",
        "to" => "https://example.com/users/alyssa",
        "content" => "I take it all back."
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> sign_and_send("/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 422)
  end

  test "server inbox MAY respond to get (non-normative)", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/inbox")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollection\""
    assert json_body =~ "\"first\""
    assert json_body =~ "/users/alyssa/inbox"
  end

  test "server inbox MUST be orderedCollection", %{conn: conn} do
    _ = user_fixtures()

    conn =
      conn
      |> Plug.Conn.put_req_header("accept", "application/activity+json")
      |> get("/users/alyssa/inbox?page=true")

    assert json_body = response(conn, 200)
    assert json_body =~ "\"OrderedCollectionPage\""
    assert json_body =~ "/users/alyssa/inbox?page=true"
  end

  test "server security considerations inbox MAY verify content posted by actor (non-normative)",
       %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Create",
      "id" =>
        "https://chatty.example/users/charlie/activities/a29a6843-9feb-4c74-a7f7-081b9c9201d3",
      "to" => "https://example.com/users/alyssa",
      "actor" => "https://chatty.example/users/charlie",
      "object" => %{
        "type" => "Note",
        "id" =>
          "https://chatty.example/users/charlie/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19",
        "to" => "https://example.com/users/alyssa",
        "attributedTo" => "https://chatty.example/users/charlie",
        "content" => "Say, did you finish reading that book I lent you?"
      }
    }

    %{ben: %{user: ben, keys: keys_pem}} = user_fixtures()
    conn = sign_and_send(conn, "/users/alyssa/inbox", Jason.encode!(activity), ben, keys_pem)

    assert response(conn, 401)
  end

  defp follow_ben_request(alyssa) do
    follow = %{
      "type" => "Follow",
      "actor" => "https://example.com/users/alyssa",
      "object" => "https://chatty.example/users/ben"
    }

    activity =
      %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "to" => "https://chatty.example/users/ben"
      }
      |> Map.merge(follow)

    Phoenix.ConnTest.build_conn()
    |> log_in_user(alyssa)
    |> Plug.Conn.put_req_header("content-type", "application/activity+json")
    |> post("/users/alyssa/outbox", Jason.encode!(activity))

    recipients = Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
    assert Enum.count(recipients) == 1
    {url, %{json: body}} = List.first(recipients)
    assert url == "https://chatty.example/users/ben/inbox"
    assert body["type"] == "Follow"
    assert body["id"]

    Map.put(follow, "id", body["id"])
  end

  defp count_inbox_items(coll_id \\ "https://example.com/users/alyssa/inbox")
       when is_binary(coll_id) do
    case MockRequestHelper.get_page(coll_id, nil) do
      {:ok,
       %{
         properties: %{
           "orderedItems" => %P.OrderedItems{values: values}
         }
       } = _outbox_page} ->
        Enum.count(values)

      _ ->
        0
    end
  end
end
