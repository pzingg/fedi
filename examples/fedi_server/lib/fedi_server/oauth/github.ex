defmodule FediServer.Oauth.Github do
  @moduledoc """
  Client for an established GitHub application.

  Setup:

  ```
  config :fedi_server, :github,
    client_id: "some client id",
    client_secret: "some client secret"
  ```
  """

  require Logger

  alias FediServer.HTTPClient

  def authorize_url() do
    state = FediServer.Oauth.random_string()
    query = URI.encode_query([{:client_id, client_id()}, {:state, state}, {:scope, "user:email"}])

    %URI{
      scheme: "https",
      port: 443,
      host: "github.com",
      path: "/login/oauth/authorize",
      query: query
    }
    |> URI.to_string()
  end

  def exchange_access_token(state, code) do
    state
    |> fetch_exchange_response(code)
    |> fetch_user_info()
    |> fetch_emails()
  end

  defp fetch_exchange_response(state, code) do
    resp =
      request(
        :post,
        "github.com",
        "/login/oauth/access_token",
        [state: state, code: code, client_secret: secret()],
        [{"accept", "application/json"}]
      )

    with {:ok, resp} <- resp,
         %{"access_token" => token} <- Jason.decode!(resp) do
      {:ok, token}
    else
      {:error, _reason} = error -> error
      %{} = resp -> {:error, {:bad_response, resp}}
    end
  end

  defp fetch_user_info({:error, _reason} = error), do: error

  # {
  #  "login": "pzingg",
  #  "id": 7576,
  #  "node_id": "MDQ6VXNlcjc1NzY=",
  #  "avatar_url": "https://avatars.githubusercontent.com/u/7576?v=4",
  #  "gravatar_id": "",
  #  "url": "https://api.github.com/users/pzingg",
  #  "html_url": "https://github.com/pzingg",
  #  "followers_url": "https://api.github.com/users/pzingg/followers",
  #  "following_url": "https://api.github.com/users/pzingg/following{/other_user}",
  #  "gists_url": "https://api.github.com/users/pzingg/gists{/gist_id}",
  #  "starred_url": "https://api.github.com/users/pzingg/starred{/owner}{/repo}",
  #  "subscriptions_url": "https://api.github.com/users/pzingg/subscriptions",
  #  "organizations_url": "https://api.github.com/users/pzingg/orgs",
  #  "repos_url": "https://api.github.com/users/pzingg/repos",
  #  "events_url": "https://api.github.com/users/pzingg/events{/privacy}",
  #  "received_events_url": "https://api.github.com/users/pzingg/received_events",
  #  "type": "User",
  #  "site_admin": false,
  #  "name": "Peter Zingg",
  #  "company": null,
  #  "blog": "",
  #  "location": "SF Bay Area",
  #  "email": null,
  #  "hireable": null,
  #  "bio": null,
  #  "twitter_username": null,
  #  "public_repos": 93,
  #  "public_gists": 7,
  #  "followers": 9,
  #  "following": 1,
  #  "created_at": "2008-04-16T15:15:59Z",
  #  "updated_at": "2023-02-28T02:36:19Z"
  # }
  defp fetch_user_info({:ok, token}) do
    resp =
      request(
        :get,
        "api.github.com",
        "/user",
        [],
        [{"accept", "application/vnd.github.v3+json"}, {"authorization", "Bearer #{token}"}]
      )

    case resp do
      {:ok, info} ->
        info = Jason.decode!(info)

        {:ok, %{info: info, token: token}}

      {:error, _reason} = error ->
        error
    end
  end

  defp fetch_emails({:error, _} = err), do: err

  # [
  #  {
  #    "email": "peter.zingg@gmail.com",
  #    "primary": true,
  #    "verified": true,
  #    "visibility": "private"
  #  },
  #  {
  #    "email": "pzingg@users.noreply.github.com",
  #    "primary": false,
  #    "verified": true,
  #    "visibility": null
  #  },
  #  {
  #    "email": "peter@chemelion.ai",
  #    "primary": false,
  #    "verified": true,
  #    "visibility": null
  #  }
  # ]
  defp fetch_emails({:ok, user}) do
    resp =
      request(
        :get,
        "api.github.com",
        "/user/emails",
        [],
        [{"accept", "application/vnd.github.v3+json"}, {"authorization", "Bearer #{user.token}"}]
      )

    case resp do
      {:ok, info} ->
        emails = Jason.decode!(info)
        {:ok, Map.merge(user, %{primary_email: primary_email(emails), emails: emails})}

      {:error, _reason} = error ->
        error
    end
  end

  defp client_id, do: FediServer.config([:github, :client_id])
  defp secret, do: FediServer.config([:github, :client_secret])

  defp request(method, host, path, query, headers, body \\ "") when method in [:get, :post] do
    query = URI.encode_query([{:client_id, client_id()} | query])

    url =
      %URI{scheme: "https", port: 443, host: host, path: path, query: query}
      |> URI.to_string()

    app_agent = Fedi.Application.app_agent()
    transport = HTTPClient.anonymous(app_agent)

    headers =
      headers ++
        [
          {"accept-charset", "utf-8"},
          {"user-agent", "#{transport.app_agent} #{transport.user_agent}"}
        ]

    opts = [
      method: method,
      url: url,
      headers: headers,
      body: body
    ]

    case Tesla.request(transport.client, opts) do
      {:error, reason} ->
        Logger.error("#{method} #{url} failed (#{reason})")
        {:error, reason}

      {:ok, %Tesla.Env{body: body} = env} ->
        if HTTPClient.success?(env.status) do
          {:ok, body}
        else
          Logger.error("#{method} #{url} #{env.status} body #{body}")
          {:error, "#{method} #{url} returned status #{env.status}"}
        end
    end
  end

  defp primary_email(emails) do
    Enum.find(emails, fn email -> email["primary"] end)["email"] || Enum.at(emails, 0)
  end
end
