defmodule FediServer.Oauth.Mastodon do
  @moduledoc """
  Oauth client to create a Mastodon application.

  Setup:

  ```
  config :fedi_server, :mastodon,
    client_name: "my app name",
    server: "https://mastodon.cloud"
  ```
  """

  require Logger

  alias FediServer.HTTPClient
  alias FediServer.Oauth.MastodonApp
  alias FediServer.Oauth.LoginCache

  @enforce_keys [:app_id, :server_url, :client_id, :client_secret, :scope, :redirect_uri]
  defstruct [
    :app_id,
    :server_url,
    :client_id,
    :client_secret,
    :scope,
    :redirect_uri,
    :email,
    :password,
    :inserted_at
  ]

  @default_scopes ["read", "write", "follow", "push"]

  @doc """
  Registers a new app with given `client_name` on a `server` with given `scopes`.
  The basic scopes are "read", "write", "follow" and "push".
  More granular scopes are available, please refer to Mastodon documentation

  Specify `redirect_uris` if you want users to be redirected to a certain page after authenticating in an OAuth flow.
  You can specify multiple URLs by passing a list. Note that if you wish to use OAuth authentication with redirects,
  the redirect URI must be one of the URLs specified here.
  Specify `to_file` to persist your app's info to a file so you can use it in the constructor.
  Specify `website` to give a website for your app.

  Presently, app registration is open by default, but this is not guaranteed to be the case for all
  Mastodon instances in the future.

  Returns `client_id` and `client_secret`, both as strings.
  """
  def create_app(client_name, server_url, redirect_uri \\ nil, scopes \\ nil, opts \\ []) do
    headers = [{"accept", "application/json"}, {"content-type", "application/json"}]

    redirect_uri = redirect_uri || "urn:ietf:wg:oauth:2.0:oob"
    scopes = scopes || @default_scopes

    request_data = %{
      "client_name" => client_name,
      "scopes" => Enum.join(scopes, " "),
      "redirect_uris" => redirect_uri
    }

    request_data =
      case Keyword.get(opts, :website) do
        nil -> request_data
        website -> Map.put(request_data, "website", website)
      end

    body = Jason.encode!(request_data)

    case request(:post, server_url, "/api/v1/apps", [], headers, body) do
      {:ok, data} ->
        params =
          Jason.decode!(data)
          |> Map.merge(request_data)
          |> Map.put("server_url", server_url)

        FediServer.Oauth.create_mastodon_app(params)

      error ->
        error
    end
  end

  def authorize_url(%MastodonApp{} = app, opts \\ []) do
    state = FediServer.Oauth.random_string()
    client_id = app.client_id
    scope = app.scopes
    redirect_uri = String.split(app.redirect_uris, " ") |> hd()

    login_data = %__MODULE__{
      app_id: app.id,
      server_url: app.server_url,
      client_id: client_id,
      client_secret: app.client_secret,
      scope: scope,
      redirect_uri: redirect_uri,
      email: Keyword.get(opts, :email),
      password: Keyword.get(opts, :password)
    }

    LoginCache.cache(:mastodon_login_cache, state, login_data)

    query = [
      {:response_type, "code"},
      {:state, state},
      {:client_id, client_id},
      {:scope, scope},
      {:redirect_uri, redirect_uri},
      {:force_login, Keyword.get(opts, :force_login, false)}
    ]

    app.server_url
    |> URI.parse()
    |> struct(path: "/oauth/authorize", query: URI.encode_query(query))
    |> URI.to_string()
  end

  def exchange_access_token(state, code) do
    case LoginCache.lookup(:mastodon_login_cache, state) do
      {:ok, %__MODULE__{} = login_data} ->
        code
        |> fetch_exchange_response(login_data)
        |> fetch_user_info(login_data)

      {:error, reason} = error ->
        Logger.error("Cache failure on #{state}: #{reason}")
        error
    end
  end

  defp fetch_exchange_response(code, %{
         server_url: server_url,
         client_id: client_id,
         client_secret: client_secret,
         scope: scope,
         redirect_uri: redirect_uri
       }) do
    data = %{
      grant_type: "authorization_code",
      code: code,
      client_id: client_id,
      client_secret: client_secret,
      scope: scope,
      redirect_uri: redirect_uri
    }

    resp =
      request(
        :post,
        server_url,
        "/oauth/token",
        [],
        [{"accept", "application/json"}, {"content-type", "application/x-www-form-urlencoded"}],
        URI.encode_query(data)
      )

    with {:ok, resp} <- resp,
         %{"access_token" => token} <- Jason.decode!(resp) do
      {:ok, token}
    else
      {:error, _reason} = error -> error
      %{} = resp -> {:error, {:bad_response, resp}}
    end
  end

  defp fetch_user_info({:error, _reason} = error, _), do: error

  # Get account information for logged in user
  # {
  #  "id": "18356",
  #  "username": "pzingg",
  #  "acct": "pzingg",
  #  "display_name": "Peter Zingg :verified:",
  #  "locked": false,
  #  "bot": false,
  #  "discoverable": true,
  #  "group": false,
  #  "created_at": "2017-04-07T00:00:00.000Z",
  #  "note": "\u003cp\u003eNorthern California. \u003ca href=\"https://mastodon.cloud/tags/art\" class=\"mention hashtag\" rel=\"tag\"\u003e#\u003cspan\u003eart\u003c/span\u003e\u003c/a\u003e \u003ca href=\"https://mastodon.cloud/tags/languages\" class=\"mention hashtag\" rel=\"tag\"\u003e#\u003cspan\u003elanguages\u003c/span\u003e\u003c/a\u003e \u003ca href=\"https://mastodon.cloud/tags/architecture\" class=\"mention hashtag\" rel=\"tag\"\u003e#\u003cspan\u003earchitecture\u003c/span\u003e\u003c/a\u003e \u003ca href=\"https://mastodon.cloud/tags/cities\" class=\"mention hashtag\" rel=\"tag\"\u003e#\u003cspan\u003ecities\u003c/span\u003e\u003c/a\u003e \u003ca href=\"https://mastodon.cloud/tags/film\" class=\"mention hashtag\" rel=\"tag\"\u003e#\u003cspan\u003efilm\u003c/span\u003e\u003c/a\u003e \u003ca href=\"https://mastodon.cloud/tags/software\" class=\"mention hashtag\" rel=\"tag\"\u003e#\u003cspan\u003esoftware\u003c/span\u003e\u003c/a\u003e \u003ca href=\"https://mastodon.cloud/tags/savecaliforniascoast\" class=\"mention hashtag\" rel=\"tag\"\u003e#\u003cspan\u003esavecaliforniascoast\u003c/span\u003e\u003c/a\u003e\u003c/p\u003e",
  #  "url": "https://mastodon.cloud/@pzingg",
  #  "avatar": "https://media.mastodon.cloud/accounts/avatars/000/018/356/original/8fb7c58e48468071.jpg",
  #  "avatar_static": "https://media.mastodon.cloud/accounts/avatars/000/018/356/original/8fb7c58e48468071.jpg",
  #  "header": "https://media.mastodon.cloud/accounts/headers/000/018/356/original/49c0bc5770673923.jpg",
  #  "header_static": "https://media.mastodon.cloud/accounts/headers/000/018/356/original/49c0bc5770673923.jpg",
  #  "followers_count": 45,
  #  "following_count": 41,
  #  "statuses_count": 251,
  #  "last_status_at": "2023-03-16",
  #  "noindex": false,
  #  "source": {...},
  #  "emojis": [...],
  #  "roles": [...],
  #  "fields": [...],
  #  "role": {...}
  # }
  defp fetch_user_info({:ok, token}, %{server_url: server_url}) do
    resp =
      request(
        :get,
        server_url,
        "/api/v1/accounts/verify_credentials",
        [],
        [{"accept", "application/json"}, {"authorization", "Bearer " <> token}]
      )

    case resp do
      {:ok, resp} ->
        %{"username" => nickname, "url" => url} = info = Jason.decode!(resp)

        # Kludge
        domain = URI.parse(url).host
        email = "#{nickname}@#{domain}"

        {:ok, %{info: info, token: token, email: email, nickname: nickname}}

      {:error, _reason} = error ->
        error
    end
  end

  defp request(method, base_url, path, query, headers, body \\ "") when method in [:get, :post] do
    query = URI.encode_query(query)

    url =
      base_url
      |> URI.parse()
      |> struct(path: path, query: query)
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
end
