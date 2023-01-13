defmodule FediServerWeb.WebFingerTest do
  use FediServer.DataCase, async: false

  import FediServer.FixturesHelper

  require Logger

  alias FediServerWeb.WebFinger

  setup do
    Tesla.Mock.mock_global(fn
      %{
        method: :get,
        url: "https://mastodon.cloud/.well-known/webfinger?resource=acct:pzingg@mastodon.cloud"
      } ->
        case Path.join(:code.priv_dir(:fedi_server), "webfinger-pzingg.json") |> File.read() do
          {:ok, contents} ->
            %Tesla.Env{
              status: 200,
              body: contents,
              headers: [{"content-type", "application/jrd+json; charset=utf-8"}]
            }

          _ ->
            Logger.error("Failed get webfinger")
            %Tesla.Env{status: 404, body: "Not found"}
        end

      %{
        method: :get,
        url: "https://mastodon.cloud/.well-known/host-meta"
      } ->
        case Path.join(:code.priv_dir(:fedi_server), "host-meta.xml") |> File.read() do
          {:ok, contents} ->
            %Tesla.Env{
              status: 200,
              body: contents,
              headers: [{"content-type", "application/xrd+xml; charset=utf-8"}]
            }

          _ ->
            Logger.error("Failed get host-meta")
            %Tesla.Env{status: 404, body: "Not found"}
        end

      %{method: method, url: url} = other ->
        Logger.error("Unhandled #{method} #{url}")
        %Tesla.Env{status: 404, body: "Not found"}
    end)

    :ok
  end

  test "gets webfinger for local user" do
    _ = user_fixtures()

    resource = "acct:alyssa@example.com"
    assert {:ok, data} = WebFinger.webfinger(resource, :json)
    assert is_map(data)

    assert data ==
             %{
               "aliases" => ["https://example.com/users/alyssa"],
               "links" => [
                 %{
                   "href" => "https://example.com/users/alyssa",
                   "rel" => "self",
                   "type" => "application/activity+json"
                 }
               ],
               "subject" => "acct:alyssa@example.com"
             }
  end

  test "gets mastodon.cloud webfinger data" do
    assert {:ok, data} = WebFinger.finger("@pzingg@mastodon.cloud")
    assert is_map(data)

    assert data == %{
             "ap_id" => "https://mastodon.cloud/users/pzingg",
             "subject" => "acct:pzingg@mastodon.cloud",
             "subscribe_address" => "https://mastodon.cloud/authorize_interaction?uri={uri}"
           }
  end
end
