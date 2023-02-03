defmodule FediServerWeb.InboxDeliveryTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  require Logger

  alias Fedi.Streams.Utils
  alias FediServer.Activities

  @webfinger_prefix "https://example.com/.well-known/webfinger?resource=acct:"

  @remote_fingers %{
    "https://chatty.example/users/ben" => "ben@chatty.example",
    "https://chatty.example/users/emilia" => "emilia@chatty.example",
    "https://other.example/users/charlie" => "charlie@other.example"
  }
  @remote_actors %{
    "https://chatty.example/users/ben" => "ben.json",
    "https://chatty.example/users/emilia" => "emilia.json",
    "https://other.example/users/charlie" => "charlie.json"
  }
  @remote_shared_inboxes [
    "https://chatty.example/inbox",
    "https://other.example/inbox"
  ]
  @local_actors [
    "https://example.com/users/alyssa",
    "https://example.com/users/daria"
  ]

  @followers_agent Module.concat(__MODULE__, "Followers")

  setup do
    _ = Agent.start_link(fn -> [] end, name: __MODULE__)
    _ = Agent.start_link(fn -> %{} end, name: @followers_agent)

    Tesla.Mock.mock_global(fn
      # When we're getting info from ben's server
      %{
        method: :get,
        url: "https://chatty.example/.well-known/host-meta"
      } ->
        xml = FediServerWeb.WebFinger.host_meta()
        %Tesla.Env{status: 200, body: xml, headers: [{"content-type", "application/xrd+xml"}]}

      # When we lookup ben and charlie
      %{
        method: :get,
        url: url
      } ->
        cond do
          String.starts_with?(url, @webfinger_prefix) ->
            user = String.replace_leading(url, @webfinger_prefix, "")
            mock_webfinger(user)

          String.contains?(url, "/outbox") ->
            mock_outbox(url)

          String.contains?(url, "/followers") ->
            mock_followers(url)

          true ->
            mock_actor(url)
        end

      # When we deliver message to a remote actors inbox
      %{
        method: :post,
        url: url,
        headers: headers,
        body: body
      } ->
        actor_url = String.replace_trailing(url, "/inbox", "")

        cond do
          Enum.member?(@remote_shared_inboxes, url) ->
            Logger.error("Delivered to shared inbox #{url}")

            Agent.update(__MODULE__, fn acc ->
              [{url, %{headers: headers, json: Jason.decode!(body)}} | acc]
            end)

            %Tesla.Env{status: 202, body: "Accepted"}

          Enum.member?(@local_actors, actor_url) ->
            # Actor.handle_post_inbox?
            type = Jason.decode!(body) |> Map.get("type", "activity")
            Logger.error("#{actor_url} got a #{type}")

            Agent.update(__MODULE__, fn acc ->
              [{url, %{headers: headers, json: Jason.decode!(body)}} | acc]
            end)

            %Tesla.Env{status: 202, body: "Accepted"}

          Map.has_key?(@remote_actors, actor_url) ->
            Agent.update(__MODULE__, fn acc ->
              [{url, %{headers: headers, json: Jason.decode!(body)}} | acc]
            end)

            %Tesla.Env{status: 202, body: "Accepted"}

          true ->
            Logger.error("Unmocked actor #{url}")
            %Tesla.Env{status: 404, body: "Not found"}
        end

      %{method: method, url: url} ->
        Logger.error("Unhandled #{method} #{url}")
        %Tesla.Env{status: 404, body: "Not found"}
    end)

    :ok
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

    # Making up a "todo" collection as the target
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
        "id" => "https://example.com/users/alyssa/todo"
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

  defp mock_webfinger(actor_id) do
    case Map.get(@remote_fingers, actor_id) do
      nil ->
        Logger.error("Unmocked actor #{actor_id}")
        %Tesla.Env{status: 404, body: "Not found"}

      acct ->
        webfinger = %{
          "subject" => "acct:#{acct}",
          "aliases" => [actor_id],
          "links" => [
            %{
              "rel" => "self",
              "type" => "application/activity+json",
              "href" => actor_id
            }
          ]
        }

        %Tesla.Env{
          status: 200,
          body: Jason.encode!(webfinger),
          headers: [{"content-type", "application/json"}]
        }
    end
  end

  defp mock_followers(url) do
    %URI{path: path, query: query} = uri = URI.parse(url)
    followers_id = Utils.base_uri(uri) |> URI.to_string()
    actor = Utils.base_uri(uri, String.replace_trailing(path, "/followers", ""))

    followers =
      Agent.get(@followers_agent, fn state -> state end)
      |> Map.get(actor, [])

    total_items = Enum.count(followers)

    oc =
      if query && String.contains?(query, "page") do
        %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "type" => "OrderedCollectionPage",
          "id" => followers_id <> "?page=true",
          "partOf" => followers_id,
          "orderedItems" => followers
        }
      else
        %{
          "@context" => "https://www.w3.org/ns/activitystreams",
          "type" => "OrderedCollectionPage",
          "id" => followers_id,
          "first" => followers_id <> "?page=true",
          "totalItems" => total_items
        }
      end

    Logger.error("#{total_items} followers for #{actor}")
    %Tesla.Env{status: 200, body: Jason.encode!(oc)}
  end

  defp mock_outbox(url) do
    %URI{path: path} = uri = URI.parse(url)
    actor = Utils.base_uri(uri, String.replace_trailing(path, "/outbox", ""))

    Logger.error("returning 403 for outbox of #{actor}")
    %Tesla.Env{status: 403, body: "Forbidden"}
  end

  defp mock_actor(url) do
    case Map.get(@remote_actors, url) do
      nil ->
        Logger.error("Unmocked actor #{url}")
        %Tesla.Env{status: 404, body: "Not found"}

      filename ->
        case Path.join(:code.priv_dir(:fedi_server), filename) |> File.read() do
          {:ok, contents} ->
            %Tesla.Env{
              status: 200,
              body: contents,
              headers: [{"content-type", "application/jrd+json; charset=utf-8"}]
            }

          _ ->
            Logger.error("Failed to load #{filename}")
            %Tesla.Env{status: 404, body: "Not found"}
        end
    end
  end
end
