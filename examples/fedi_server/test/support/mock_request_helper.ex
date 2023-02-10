defmodule FediServerWeb.MockRequestHelper do
  @moduledoc """
  Sets up Tesla mock and two agents to track requests and followers.
  """

  require Logger

  alias Fedi.Streams.Utils
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Activities

  @webfinger_regex ~r/^.+\/.well-known\/webfinger\?resource=acct:/

  @remote_fingers [
    {"https://chatty.example/users/ben", "ben@chatty.example"},
    {"https://chatty.example/users/emilia", "emilia@chatty.example"},
    {"https://other.example/users/charlie", "charlie@other.example"},
    {"https://mastodon.cloud/users/pzingg", "pzingg@mastodon.cloud"},
    {"https://mastodon.social/users/judell", "judell@mastodon.social"}
  ]
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

  def remote_actors, do: Map.keys(@remote_actors)

  def setup_mocks(module) do
    followers_module = Module.concat(module, "Followers")
    _ = Agent.start_link(fn -> [] end, name: module)
    _ = Agent.start_link(fn -> %{} end, name: followers_module)

    Tesla.Mock.mock_global(fn
      # When we lookup ben and charlie
      %{
        method: :get,
        url: url
      } ->
        cond do
          String.contains?(url, "/.well-known/host-meta") ->
            xml = FediServerWeb.WebFinger.host_meta()
            %Tesla.Env{status: 200, body: xml, headers: [{"content-type", "application/xrd+xml"}]}

          Regex.run(@webfinger_regex, url, return: :index) |> is_list() ->
            account = String.replace(url, @webfinger_regex, "")
            mock_webfinger(account)

          String.contains?(url, "/outbox") ->
            mock_outbox(url)

          String.contains?(url, "/followers") ->
            mock_followers(url, followers_module)

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
        actor_iri = String.replace_trailing(url, "/inbox", "")

        cond do
          Enum.member?(@remote_shared_inboxes, url) ->
            Logger.error("Delivered to shared inbox #{url}")

            Agent.update(module, fn acc ->
              [{url, %{headers: headers, json: Jason.decode!(body)}} | acc]
            end)

            %Tesla.Env{status: 202, body: "Accepted"}

          Enum.member?(@local_actors, actor_iri) ->
            # Actor.handle_post_inbox?
            type = Jason.decode!(body) |> Map.get("type", "activity")
            Logger.error("#{actor_iri} got a #{type}")

            Agent.update(module, fn acc ->
              [{url, %{headers: headers, json: Jason.decode!(body)}} | acc]
            end)

            %Tesla.Env{status: 202, body: "Accepted"}

          Map.has_key?(@remote_actors, actor_iri) ->
            Agent.update(module, fn acc ->
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

  defp mock_webfinger(actor_id) do
    case Enum.find(@remote_fingers, fn {url, acct} -> url == actor_id || acct == actor_id end) do
      nil ->
        %Tesla.Env{
          status: 404,
          body: "Account #{actor_id} not found",
          headers: [{"content-type", "application/json"}]
        }

      {url, acct} ->
        webfinger = %{
          "subject" => "acct:#{acct}",
          "aliases" => [url],
          "links" => [
            %{
              "rel" => "self",
              "type" => "application/activity+json",
              "href" => url
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

  defp mock_followers(url, followers_module) do
    %URI{path: path, query: query} = uri = URI.parse(url)
    followers_id = Utils.base_uri(uri) |> URI.to_string()
    actor = Utils.base_uri(uri, String.replace_trailing(path, "/followers", ""))

    followers =
      Agent.get(followers_module, fn state -> state end)
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

  def get_page(coll_id, viewer_ap_id \\ nil)

  def get_page(coll_id, nil) when is_binary(coll_id) do
    Utils.to_uri(coll_id) |> Activities.get_collection_unfiltered()
  end

  def get_page(coll_id, viewer_ap_id) when is_binary(coll_id) and is_binary(viewer_ap_id) do
    viewer_ap_id =
      if Activities.local?(Utils.to_uri(viewer_ap_id)) do
        viewer_ap_id
      else
        nil
      end

    opts = APUtils.collection_opts(%{"page" => "true"}, viewer_ap_id)
    Utils.to_uri(coll_id) |> Activities.get_collection(opts)
  end
end
