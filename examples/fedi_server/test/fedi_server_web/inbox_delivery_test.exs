defmodule FediServerWeb.InboxDeliveryTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  require Logger

  alias FediServer.Activities

  setup do
    FediServerWeb.MockRequestHelper.setup_mocks(__MODULE__)
  end

  test "inbox delivery MUST perform delivery", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => ["https://chatty.example/users/ben", "https://other.example/users/charlie"],
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Check that the activities were delivered to ben and charlie
    requests = Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)

    recipients = Enum.map(requests, fn {url, _} -> url end)

    assert Enum.sort(recipients) ==
             Enum.sort([
               "https://chatty.example/users/ben/inbox",
               "https://other.example/users/charlie/inbox"
             ])
  end

  test "inbox delivery MUST determine all recipients", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://example.com/users/alyssa/followers",
      "bto" => "https://chatty.example/users/ben",
      "bcc" => "https://other.example/users/charlie",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Check that the activities were delivered to ben and charlie
    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    # FIXME: Alyssa is sender, she should not get delivered
    assert Enum.sort(recipients) ==
             Enum.sort([
               "https://chatty.example/users/ben/inbox",
               "https://other.example/users/charlie/inbox"
             ])
  end

  test "inbox delivery MUST add id", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://chatty.example/users/ben",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Get the payload that was delivered to ben
    [{"https://chatty.example/users/ben/inbox", %{json: payload}}] =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)

    assert is_map(payload)
    assert payload["type"] == "Create"
    assert payload["id"]
  end

  test "inbox delivery MUST submit with credentials", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://chatty.example/users/ben",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Get the payload that was delivered to ben
    [{"https://chatty.example/users/ben/inbox", %{headers: headers}}] =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)

    headers = Map.new(headers)
    assert digest = headers["digest"]
    assert String.starts_with?(digest, "SHA-256=")
    assert signature = headers["signature"]
    assert String.contains?(signature, "keyId=\"https://example.com/users/alyssa#main-key\"")
    assert String.contains?(signature, "algorithm=\"rsa-sha256\"")
    assert String.contains?(signature, "headers=")
    assert String.contains?(signature, "signature=")
  end

  test "inbox delivery MUST deliver to collection", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://example.com/users/alyssa/followers",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    # Add daria, ben and charlie to alyssa's followers
    Activities.follow("https://chatty.example/users/ben", "https://example.com/users/alyssa")
    Activities.follow("https://other.example/users/charlie", "https://example.com/users/alyssa")
    Activities.follow("https://example.com/users/daria", "https://example.com/users/alyssa")

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    assert Enum.sort(recipients) ==
             Enum.sort([
               "https://chatty.example/users/ben/inbox",
               "https://other.example/users/charlie/inbox",
               "https://example.com/users/daria/inbox"
             ])
  end

  test "inbox delivery deliver to collection MUST deliver recursively", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://example.com/users/alyssa/followers",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    # Add daria and her followers to alyssa's followers
    # Add ben and charlie to daria's followers
    Activities.follow("https://example.com/users/daria", "https://example.com/users/alyssa")

    Activities.follow(
      "https://example.com/users/daria/followers",
      "https://example.com/users/alyssa"
    )

    Activities.follow("https://chatty.example/users/ben", "https://example.com/users/daria")
    Activities.follow("https://other.example/users/charlie", "https://example.com/users/daria")

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    assert Enum.sort(recipients) ==
             Enum.sort([
               "https://chatty.example/users/ben/inbox",
               "https://other.example/users/charlie/inbox",
               "https://example.com/users/daria/inbox"
             ])
  end

  test "inbox delivery MUST deliver with object for certain activities", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://chatty.example/users/ben",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Get the payload that was delivered to ben
    [{"https://chatty.example/users/ben/inbox", %{json: payload}}] =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)

    assert is_map(payload)
    assert payload["type"] == "Create"
    assert payload["object"]
    assert payload["object"]["type"] == "Note"
  end

  test "inbox delivery MUST deliver with target for certain activities", %{conn: conn} do
    {users, _activities, [note | _]} = outbox_fixtures()

    # Using the "featured" collection as the target
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Add",
      "to" => "https://chatty.example/users/ben",
      "actor" => "https://example.com/users/alyssa",
      "object" => %{
        "type" => "Note",
        "id" => note.ap_id
      },
      "target" => %{
        "type" => "OrderedCollection",
        "id" => "https://example.com/users/alyssa/collections/featured"
      }
    }

    %{alyssa: %{user: alyssa}} = users

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    # Get the payload that was delivered to ben
    [{"https://chatty.example/users/ben/inbox", %{json: payload}}] =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)

    assert is_map(payload)
    assert payload["type"] == "Add"
    assert payload["target"]
    assert payload["target"]["type"] == "OrderedCollection"
  end

  test "inbox delivery MUST deduplicate final recipient list", %{conn: conn} do
    # Sending to ben and to alyssa's followers (which includes ben)
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://example.com/users/alyssa/followers",
      "cc" => "https://chatty.example/users/ben",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    # Add daria, ben and charlie to alyssa's followers
    Activities.follow("https://chatty.example/users/ben", "https://example.com/users/alyssa")
    Activities.follow("https://other.example/users/charlie", "https://example.com/users/alyssa")
    Activities.follow("https://example.com/users/daria", "https://example.com/users/alyssa")

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    assert Enum.count(recipients) == 3

    assert Enum.sort(recipients) ==
             Enum.sort([
               "https://chatty.example/users/ben/inbox",
               "https://other.example/users/charlie/inbox",
               "https://example.com/users/daria/inbox"
             ])
  end

  test "inbox delivery MUST NOT deliver to actor", %{conn: conn} do
    # Sending to ben and to alyssa's followers (which includes ben)
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://example.com/users/alyssa/followers",
      "cc" => "https://example.com/users/alyssa",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    # Add ben to alyssa's followers
    Activities.follow("https://chatty.example/users/ben", "https://example.com/users/alyssa")

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    assert Enum.sort(recipients) ==
             Enum.sort([
               "https://chatty.example/users/ben/inbox"
             ])
  end

  test "inbox delivery SHOULD NOT deliver block", %{conn: conn} do
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Block",
      "to" => "https://other.example/users/charlie",
      "cc" => "https://www.w3.org/ns/activitystreams#Public",
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

    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    assert recipients == []
  end

  test "inbox delivery sharedInbox MAY deliver", %{conn: conn} do
    # Sending to ben and emilia who have the same shared inbox
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://chatty.example/users/ben",
      "cc" => "https://chatty.example/users/emilia",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    assert Enum.sort(recipients) == Enum.sort(["https://chatty.example/inbox"])
  end

  test "inbox delivery sharedInbox MUST deliver to inbox if no sharedInbox", %{conn: conn} do
    # Sending to charlie who doesn't have a shared inbox
    activity = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Note",
      "to" => "https://other.example/users/charlie",
      "attributedTo" => "https://example.com/users/alyssa",
      "content" => "Say, did you finish reading that book I lent you?"
    }

    %{alyssa: %{user: alyssa}} = user_fixtures()

    conn =
      conn
      |> log_in_user(alyssa)
      |> Plug.Conn.put_req_header("content-type", "application/activity+json")
      |> post("/users/alyssa/outbox", Jason.encode!(activity))

    assert response(conn, 201)

    recipients =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)
      |> Enum.map(fn {url, _} -> url end)

    assert Enum.sort(recipients) == Enum.sort(["https://other.example/users/charlie/inbox"])
  end
end
