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

  alias FediServer.Activities
  alias FediServer.Activities.User
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

  @doc """
  Sends a GET request signed with an HTTP Signature to obtain an
    ActivityStreams value.
  """
  def dereference(
        %__MODULE__{private_key: private_key, public_key_id: public_key_id} = transport,
        %URI{host: host, path: path} = url
      )
      when is_tuple(private_key) and is_binary(public_key_id) do
    date_str = Fedi.ActivityPub.Utils.date_header_value()

    headers_for_signature =
      [
        {"(request-target)", "get #{path}"},
        {"host", host},
        {"date", date_str}
      ]
      |> Map.new()

    signature = HTTPSignatures.sign(private_key, public_key_id, headers_for_signature)

    headers = [
      {"accept", @accept_header_value},
      {"accept-charset", "utf-8"},
      {"user-agent", "#{transport.app_agent} #{transport.user_agent}"},
      {"date", date_str},
      {"signature", signature}
    ]

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
          {:ok, body}
        else
          msg = "GET #{opts[:url]} failed (#{env.status})"
          Logger.error(msg)
          {:error, msg}
        end
    end
  end

  def dereference(%__MODULE__{} = _transport, %URI{} = url) do
    Logger.error("Can't dereference #{URI.to_string(url)}: missing private key or public key id")
    {:error, "Can't dereference #{URI.to_string(url)}: missing private key or public key id"}
  end

  @doc """
  Sends a POST request with an HTTP Signature.
  """
  def deliver(
        %__MODULE__{private_key: private_key, public_key_id: public_key_id} = transport,
        body,
        %URI{host: host, path: path} = url
      )
      when is_tuple(private_key) and is_binary(public_key_id) and is_binary(body) do
    date_str = Fedi.ActivityPub.Utils.date_header_value()
    digest = "SHA-256=" <> (:crypto.hash(:sha256, body) |> Base.encode64())

    headers_for_signature =
      [
        {"(request-target)", "post #{path}"},
        {"host", host},
        {"date", date_str},
        {"content-length", byte_size(body)},
        {"digest", digest}
      ]
      |> Map.new()

    signature = HTTPSignatures.sign(private_key, public_key_id, headers_for_signature)

    headers = [
      {"content-type", "application/activity+json"},
      {"user-agent", "#{transport.app_agent} #{transport.user_agent}"},
      {"date", date_str},
      {"content-length", byte_size(body)},
      {"digest", digest},
      {"signature", signature}
    ]

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
    Logger.error("No recipients specified for batch_deliver of #{body}")
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

  def fetch_masto_user(%__MODULE__{} = transport, %URI{path: path} = id) do
    date_str = Fedi.ActivityPub.Utils.date_header_value()
    json_url = %URI{id | path: path <> ".json"}

    headers = [
      {"accept", @accept_header_value},
      {"accept-charset", "utf-8"},
      {"user-agent", "#{transport.app_agent} #{transport.user_agent}"},
      {"date", date_str}
    ]

    opts = [
      method: :get,
      url: URI.to_string(json_url),
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

  def keys_from_pem(pem) when is_binary(pem) do
    with [private_key_code] <- :public_key.pem_decode(pem),
         private_key <- :public_key.pem_entry_decode(private_key_code),
         {:RSAPrivateKey, _, modulus, exponent, _, _, _, _, _, _, _} <- private_key do
      {:ok, private_key, {:RSAPublicKey, modulus, exponent}}
    else
      error -> {:error, error}
    end
  end

  def keys_from_pem(_), do: {:error, "No keys to decode"}

  @doc """
  Fetch a public key, given a `Plug.Conn` structure.
  """
  def fetch_public_key(%Plug.Conn{} = conn) do
    with %{"keyId" => key_id} <- HTTPSignatures.signature_for_conn(conn),
         {:ok, actor_id} <- key_id_to_actor_id(key_id),
         {:ok, public_key} <- Activities.get_public_key(actor_id) do
      {:ok, public_key}
    end
  end

  @doc """
  Refetch a public key, given a `Plug.Conn` structure.
  Called when the initial key supplied failed to validate the signature.
  """
  def refetch_public_key(%Plug.Conn{} = conn) do
    with %{"keyId" => key_id} <- HTTPSignatures.signature_for_conn(conn),
         {:ok, actor_id} <- key_id_to_actor_id(key_id),
         {:ok, %User{public_key: public_key}} <- Activities.resolve_and_insert_user(actor_id) do
      if is_binary(public_key) && public_key != "" do
        {:ok, public_key}
      else
        {:error, "No public key found"}
      end
    end
  end

  def validate_uri(%URI{scheme: scheme, host: host, path: path} = uri) do
    if Enum.member?(["http", "https"], scheme) && !is_nil(host) && host != "" &&
         !is_nil(path) && String.length(path) > 1 do
      uri
    else
      nil
    end
  end

  def key_id_to_actor_id(key_id) do
    with %URI{} = actor_id <-
           key_id
           |> URI.parse()
           |> Map.put(:fragment, nil)
           |> remove_suffix(@known_public_key_suffixes)
           |> validate_uri(),
         %{"ap_id" => ap_id} <- WebFinger.finger(actor_id) do
      {:ok, ap_id}
    else
      _ ->
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
