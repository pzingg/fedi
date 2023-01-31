defmodule FediServer.HTTPClient do
  @moduledoc """
  This module provides functions to make ActivityStreams HTTP requests
  to other servers in order to send or receive ActivityStreams data,
  using the Tesla HTTP client library, and Akkoma's HTTPSignatures library.

  The transport is responsible for setting the appropriate request headers,
  signing the requests if needed, and facilitating the traffic between this
  server and another.

  The transport is exclusively used to issue requests on behalf of an actor,
  and is never sending requests on behalf of the server in general.

  The transport makes a dereference call using HTTP signatures to
  authenticate the request on behalf of a particular actor.

  No rate limiting is applied.

  Only one request is tried per call.
  """

  @behaviour HTTPSignatures.Adapter

  require Logger

  alias Fedi.Streams.Utils
  alias FediServer.Activities
  alias FediServer.Accounts.User
  alias FediServerWeb.WebFinger

  # @accept_header_value is the Accept header value indicating that the
  # response should contain an ActivityStreams object.
  @accept_header_value "application/ld+json; profile=\"https:www.w3.org/ns/activitystreams\""
  @version "0.1.0"
  @user_agent "Fedi-#{@version}"

  @enforce_keys [:client, :app_agent, :user_agent]
  defstruct [
    :client,
    :app_agent,
    :user_agent,
    :private_key,
    :public_key_id
  ]

  @type t() :: %__MODULE__{
          client: Tesla.Client.t(),
          app_agent: String.t(),
          user_agent: String.t(),
          private_key: :public_key.rsa_private_key() | nil,
          public_key_id: String.t() | nil
        }

  @known_public_key_suffixes ["/publickey", "/main-key"]

  @doc """
  Returns a new Transport on behalf of a specific actor.

  The actor's credentials are used to add an HTTP Signature to requests, which
  requires an actor's private key, a unique identifier for their public key,
  and an HTTP Signature signing algorithm.
  """
  def credentialed(%User{ap_id: ap_id, keys: keys}, app_agent, opts \\ [])
      when is_binary(keys) and is_binary(app_agent) do
    with {:ok, private_key, _} <- keys_from_pem(keys) do
      public_key_id = ap_id <> "#main-key"

      {:ok,
       %__MODULE__{
         client: build_client(opts),
         app_agent: app_agent,
         user_agent: @user_agent,
         private_key: private_key,
         public_key_id: public_key_id
       }}
    end
  end

  @doc """
  Returns a new Transport without any actor credentials.
  """
  def anonymous(app_agent, opts \\ []) when is_binary(app_agent) do
    %__MODULE__{
      client: build_client(opts),
      app_agent: app_agent,
      user_agent: @user_agent
    }
  end

  def signed_headers(
        %URI{host: host, path: path} = url,
        private_key,
        public_key_id,
        user_agent,
        nil
      ) do
    date_str = Fedi.ActivityPub.Utils.date_header_value()

    headers_for_signature =
      [
        {"(request-target)", "get #{path}"},
        {"host", host},
        {"date", date_str}
      ]
      |> Map.new()

    signature = HTTPSignatures.sign(private_key, public_key_id, headers_for_signature)

    [
      {"accept", @accept_header_value},
      {"accept-charset", "utf-8"},
      {"user-agent"},
      {"date", date_str},
      {"signature", signature}
    ]
  end

  def signed_headers(
        %URI{host: host, path: path} = url,
        private_key,
        public_key_id,
        user_agent,
        body
      ) do
    date_str = Fedi.ActivityPub.Utils.date_header_value()
    digest = "SHA-256=" <> (:crypto.hash(:sha256, body) |> Base.encode64())
    content_length = byte_size(body) |> to_string()

    headers_for_signature =
      [
        {"(request-target)", "post #{path}"},
        {"host", host},
        {"date", date_str},
        {"content-length", content_length},
        {"digest", digest}
      ]
      |> Map.new()

    signature = HTTPSignatures.sign(private_key, public_key_id, headers_for_signature)

    [
      {"content-type", "application/activity+json"},
      {"user-agent", user_agent},
      {"date", date_str},
      {"content-length", content_length},
      {"digest", digest},
      {"signature", signature}
    ]
  end

  @doc """
  Sends a GET request signed with an HTTP Signature to obtain an
    ActivityStreams value.
  """
  def dereference(
        %__MODULE__{private_key: private_key, public_key_id: public_key_id} = transport,
        %URI{} = url
      )
      when is_tuple(private_key) and is_binary(public_key_id) do
    user_agent = "#{transport.app_agent} #{transport.user_agent}"
    headers = signed_headers(url, private_key, public_key_id, user_agent, nil)

    opts = [
      method: :get,
      url: URI.to_string(url),
      headers: headers
    ]

    case Tesla.request(transport.client, opts) do
      {:error, reason} ->
        Logger.error("GET #{opts[:url]} failed (#{reason})")
        {:error, reason}

      {:ok, %Tesla.Env{body: body} = env} ->
        if success?(env.status) do
          # Logger.debug("GET #{opts[:url]} succeeded")
          Jason.decode(body)
        else
          msg = "GET #{opts[:url]} failed (#{env.status})"
          Logger.error(msg)
          {:error, msg}
        end
    end
  end

  def dereference(%__MODULE__{} = _transport, %URI{} = url) do
    Logger.error("Can't dereference #{url}: missing private key or public key id")
    {:error, "Can't dereference #{url}: missing private key or public key id"}
  end

  @doc """
  Sends a POST request with an HTTP Signature.
  """
  def deliver(
        %__MODULE__{private_key: private_key, public_key_id: public_key_id} = transport,
        body,
        %URI{} = url
      )
      when is_tuple(private_key) and is_binary(public_key_id) and is_binary(body) do
    user_agent = "#{transport.app_agent} #{transport.user_agent}"
    headers = signed_headers(url, private_key, public_key_id, user_agent, body)

    opts = [
      method: :post,
      body: body,
      url: URI.to_string(url),
      headers: headers
    ]

    case Tesla.request(transport.client, opts) do
      {:error, reason} ->
        Logger.error("POST #{opts[:url]} failed (#{reason})")
        {:error, reason}

      {:ok, env} ->
        if success?(env.status) do
          :ok
        else
          msg = "POST #{opts[:url]} failed (#{env.status})"
          Logger.error(msg)
          {:error, msg}
        end
    end
  end

  @doc """
  Sends concurrent POST requests. Returns an error if any of the
  requests had an error.
  """
  def batch_deliver(%__MODULE__{}, body, []) do
    Logger.debug("No recipients specified for batch_deliver of #{body}")
    :ok
  end

  def batch_deliver(
        %__MODULE__{private_key: private_key, public_key_id: public_key_id} = transport,
        body,
        recipients
      )
      when is_tuple(private_key) and is_binary(public_key_id) and is_binary(body) and
             is_list(recipients) do
    # TODO Use async task or Oban jobs and wait (or don't wait) for multiple results
    errors =
      recipients
      |> Enum.map(&deliver(transport, body, &1))
      |> Enum.map(fn
        {:error, reason} -> reason
        _ -> nil
      end)
      |> Enum.filter(fn item -> !is_nil(item) end)

    if Enum.empty?(errors) do
      :ok
    else
      errors = Enum.join(errors, ", ")
      msg = "At least one failure: #{errors}"
      Logger.error(msg)
      {:error, msg}
    end
  end

  def fetch_masto_user(%__MODULE__{} = transport, id) do
    date_str = Fedi.ActivityPub.Utils.date_header_value()

    headers = [
      {"accept", @accept_header_value},
      {"accept-charset", "utf-8"},
      {"user-agent", "#{transport.app_agent} #{transport.user_agent}"},
      {"date", date_str}
    ]

    opts = [
      method: :get,
      url: URI.to_string(id),
      headers: headers
    ]

    case Tesla.request(transport.client, opts) do
      {:error, reason} ->
        Logger.error("GET #{opts[:url]} failed (#{reason})")
        {:error, reason}

      {:ok, %Tesla.Env{body: body} = env} ->
        if success?(env.status) do
          {:ok, body}
        else
          msg = "GET #{opts[:url]} failed (#{env.status})"
          Logger.error(msg)
          {:error, msg}
        end
    end
  end

  ### Implementation

  @doc """
  Returns true if the HTTP status code is either OK, Created, or Accepted.
  """
  def success?(status_code) do
    Enum.member?([200, 201, 202], status_code)
  end

  def build_client(opts \\ []) do
    middleware = [
      Tesla.Middleware.FollowRedirects,
      Tesla.Middleware.KeepRequest,
      {Tesla.Middleware.Timeout, timeout: Keyword.get(opts, :timeout, 2_000)}
    ]

    Tesla.client(middleware)
  end

  def generate_rsa_pem do
    key = :public_key.generate_key({:rsa, 2048, 65_537})
    private_key_entry = :public_key.pem_entry_encode(:RSAPrivateKey, key)
    private_key_pem = :public_key.pem_encode([private_key_entry]) |> String.trim_trailing()

    {:ok, _, public_key} = keys_from_pem(private_key_pem)
    public_key_entry = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    public_key_pem = :public_key.pem_encode([public_key_entry]) |> String.trim_trailing()

    {:ok, private_key_pem, public_key_pem}
  end

  def public_key_from_pem(public_key_pem) do
    if is_binary(public_key_pem) && public_key_pem != "" do
      with [public_key_code | _] <- :public_key.pem_decode(public_key_pem),
           public_key <- :public_key.pem_entry_decode(public_key_code) do
        {:ok, public_key}
      else
        _ ->
          {:error, "Could not decode public key"}
      end
    else
      {:error, "Missing public key"}
    end
  end

  def keys_from_pem(pem) when is_binary(pem) do
    with [private_key_code | _] <- :public_key.pem_decode(pem),
         private_key <- :public_key.pem_entry_decode(private_key_code),
         {:RSAPrivateKey, _, modulus, exponent, _, _, _, _, _, _, _} <- private_key do
      {:ok, private_key, {:RSAPublicKey, modulus, exponent}}
    else
      _ ->
        {:error, "Could not decode private key"}
    end
  end

  def keys_from_pem(_), do: {:error, "No keys to decode"}

  @doc """
  Fetch a public key, given a `Plug.Conn` structure.
  """
  def fetch_public_key(%Plug.Conn{} = conn) do
    with {:fetch_signature, %{"keyId" => key_id} = signature} <-
           {:fetch_signature, HTTPSignatures.signature_for_conn(conn)},
         {:ok, actor_id} <- key_id_to_actor_id(key_id),
         {:ok, public_key} <- Activities.get_public_key(actor_id) do
      {:ok, public_key}
    else
      {:error, reason} -> {:error, reason}
      {:fetch_signature, _} -> {:error, "No signature in connection"}
    end
  end

  @doc """
  Refetch a public key, given a `Plug.Conn` structure.
  Called when the initial key supplied failed to validate the signature.
  """
  def refetch_public_key(%Plug.Conn{} = conn) do
    with {:fetch_signature, %{"keyId" => key_id}} <-
           {:fetch_signature, HTTPSignatures.signature_for_conn(conn)},
         {:ok, actor_id} <- key_id_to_actor_id(key_id),
         {:ok, %User{} = user} <- Activities.resolve_and_insert_user(actor_id) do
      User.get_public_key(user)
    else
      {:error, reason} -> {:error, reason}
      {:fetch_signature, _} -> {:error, "No signature in connection"}
    end
  end

  def is_http_uri?(%URI{scheme: scheme, host: host, path: path} = uri) do
    Enum.member?(["http", "https"], scheme) && !is_nil(host) && host != "" &&
      !is_nil(path) && String.length(path) > 1
  end

  @doc """
  We expect key_id to be something like "@pzingg@mastodon.cloud".
  """
  def key_id_to_actor_id(key_id) do
    account =
      key_id
      |> Utils.to_uri()
      |> Utils.base_uri()
      |> remove_suffix(@known_public_key_suffixes)

    case WebFinger.finger(account) do
      {:ok, %{"ap_id" => ap_id}} ->
        {:ok, Utils.to_uri(ap_id)}

      {:error, _reason} ->
        {:error, "Could not finger #{key_id}"}
    end
  end

  defp remove_suffix(uri, [test | rest]) do
    if not is_nil(uri.path) and String.ends_with?(uri.path, test) do
      Map.put(uri, :path, String.replace(uri.path, test, ""))
    else
      remove_suffix(uri, rest)
    end
  end

  defp remove_suffix(uri, []), do: uri
end
