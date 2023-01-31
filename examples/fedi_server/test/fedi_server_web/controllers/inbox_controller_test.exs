defmodule FediServerWeb.InboxControllerTest do
  use FediServerWeb.ConnCase

  import FediServer.FixturesHelper

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityStreams.Property, as: P
  alias Fedi.ActivityStreams.Type, as: T
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Accounts.User
  alias FediServer.Activities

  @webfinger_prefix "https://example.com/.well-known/webfinger?resource=acct:"

  @remote_fingers %{
    "https://chatty.example/users/ben" => "ben@chatty.example",
    "https://other.example/users/charlie" => "charlie@other.example"
  }
  @remote_actors %{
    "https://chatty.example/users/ben" => "ben.json",
    "https://other.example/users/charlie" => "charlie.json"
  }
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

      # When we deliver message to ben's or charlie's inbox
      %{
        method: :post,
        url: url,
        body: body
      } ->
        actor_url = String.replace_trailing(url, "/inbox", "")

        cond do
          Enum.member?(@local_actors, actor_url) ->
            # Actor.handle_post_inbox?
            type = Jason.decode!(body) |> Map.get("type", "activity")
            Logger.error("#{actor_url} got a #{type}")
            Agent.update(__MODULE__, fn acc -> [{url, %{json: Jason.decode!(body)}} | acc] end)
            %Tesla.Env{status: 201, body: "Created"}

          Map.has_key?(@remote_actors, actor_url) ->
            Agent.update(__MODULE__, fn acc -> [{url, %{json: Jason.decode!(body)}} | acc] end)
            %Tesla.Env{status: 201, body: "Created"}

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
    [{"https://example.com/users/daria/inbox", %{json: payload}}] =
      Agent.get(__MODULE__, fn acc -> Enum.reverse(acc) end)

    assert is_map(payload)
    assert payload["type"] == "Create"

    assert payload["object"]["id"] ==
             "https://chatty.example/users/ben/statuses/49e2d03d-b53a-4c4c-a95c-94a6abf45a19"
  end

  test test "inbox accept create MAY be supported (non-normative)", %{conn: conn} do
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

  defp sign_and_send(conn, url, body, %User{ap_id: actor_id}, keys_pem) do
    {:ok, private_key, _} = FediServer.HTTPClient.keys_from_pem(keys_pem)

    headers =
      FediServer.HTTPClient.signed_headers(
        URI.parse(url),
        private_key,
        actor_id <> "#main-key",
        "test",
        body
      )

    Enum.reduce(headers, conn, fn {name, value}, acc ->
      Plug.Conn.put_req_header(acc, name, value)
    end)
    |> post(url, body)
  end

  defp count_inbox_items(coll_url \\ "https://example.com/users/alyssa/inbox") do
    case get_page(coll_url, nil) do
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

  defp get_posted_item(coll_url \\ "https://example.com/users/alyssa/inbox", filtered_for \\ nil) do
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
