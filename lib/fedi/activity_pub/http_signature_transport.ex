defmodule Fedi.ActivityPub.HTTPSignatureTransport do
  @moduledoc """
  Transport makes ActivityStreams calls to other servers in order to send or
  receive ActivityStreams data.

  It is responsible for setting the appropriate request headers, signing the
  requests if needed, and facilitating the traffic between this server and
  another.

  The transport is exclusively used to issue requests on behalf of an actor,
  and is never sending requests on behalf of the server in general.

  HttpSignatureTransport makes a dereference call using HTTP signatures to
  authenticate the request on behalf of a particular actor.

  No rate limiting is applied.

  Only one request is tried per call.
  """

  @behaviour HTTPSignatures.Adapter

  require Logger

  # @accept_header_value is the Accept header value indicating that the
  # response should contain an ActivityStreams object.
  @accept_header_value "application/ld+json; profile=\"https:www.w3.org/ns/activitystreams\""
  @version "0.1"

  @user_agent "Fedi-#{@version}"

  @enforce_keys [:client, :app_agent, :user_agent]
  defstruct [
    :client,
    :app_agent,
    :user_agent,
    :public_key_id,
    :private_key
  ]

  @type t() :: %__MODULE__{
          client: Tesla.Client.t(),
          app_agent: String.t(),
          user_agent: String.t(),
          public_key_id: String.t() | nil,
          private_key: String.t() | nil
        }

  @known_public_key_suffixes ["/publickey", "/main-key"]

  @doc """
  Returns a new Transport.

  It sends requests specifically on behalf of a specific actor on this server.
  The actor's credentials are used to add an HTTP Signature to requests, which
  requires an actor's private key, a unique identifier for their public key,
  and an HTTP Signature signing algorithm.

  The client lets users issue requests through any HTTP client, including the
  standard library's HTTP client.

  The app_agent uniquely identifies the calling application's requests, so peers
  may aid debugging the requests incoming from this server. Note that the
  agent string will also include one for go-fed, so at minimum peer servers can
  reach out to the go-fed library to aid in notifying implementors of malformed
  or unsupported requests.
  """
  def new(%{database: database} = _context, %URI{} = actor_id, app_agent \\ nil) do
    # FIXME could not fetch application environment :user_agent for application :fedi
    # because configuration at :user_agent was not set
    # app_agent = app_agent || Application.fetch_env!(:fedi, :user_agent)
    app_agent = app_agent || "(elixir-fedi-0.1.0)"
    public_key_id = URI.to_string(actor_id) <> "/main-key"

    private_key =
      case apply(database, :get_actor_private_key, [actor_id]) do
        {:ok, private_key} ->
          private_key

        {:error, reason} ->
          Logger.error("Failed to fetch private key for #{URI.to_string(actor_id)}: #{reason}")
          nil
      end

    %__MODULE__{
      client: build_client(),
      app_agent: app_agent,
      user_agent: @user_agent,
      public_key_id: public_key_id,
      private_key: private_key
    }
  end

  def anonymous_client(app_agent \\ nil) do
    app_agent = app_agent || Application.fetch_env!(:fedi, :user_agent)

    %__MODULE__{
      client: build_client(),
      app_agent: app_agent,
      user_agent: @user_agent
    }
  end

  @doc """
  Returns true if the HTTP status code is either OK, Created, or Accepted.
  """
  def success?(status_code) do
    Enum.member?([200, 201, 202], status_code)
  end

  def build_client() do
    middleware = [
      Tesla.Middleware.FollowRedirects,
      Tesla.Middleware.KeepRequest
    ]

    Tesla.client(middleware)
  end

  # TODO: Add Webfinger support
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
        {:error, reason}

      {:ok, %Tesla.Env{body: body} = env} ->
        if success?(env.status) do
          {:ok, body}
        else
          msg = "GET request to #{opts[:url]} failed (#{env.status})"
          Logger.error(msg)
          {:error, msg}
        end
    end
  end

  @doc """
  Sends a GET request signed with an HTTP Signature to obtain an
    ActivityStreams value.
  """
  def dereference(
        %__MODULE__{private_key: private_key, public_key_id: public_key_id} = transport,
        %URI{host: host, path: path} = url
      )
      when is_binary(private_key) and is_binary(public_key_id) do
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
        {:error, reason}

      {:ok, %Tesla.Env{body: body} = env} ->
        if success?(env.status) do
          {:ok, body}
        else
          msg = "GET request to #{opts[:url]} failed (#{env.status})"
          Logger.error(msg)
          {:error, msg}
        end
    end
  end

  def dereference(%__MODULE__{} = _transport, %URI{} = url) do
    {:error, "Can't dereference #{URI.to_string(url)}: no private key"}
  end

  @spec deliver(Fedi.ActivityPub.HTTPSignatureTransport.t(), bitstring, URI.t()) ::
          :ok | {:error, any}
  @doc """
  Sends a POST request with an HTTP Signature.
  """
  def deliver(
        %__MODULE__{private_key: private_key, public_key_id: public_key_id} = transport,
        body,
        %URI{host: host, path: path} = url
      )
      when is_binary(private_key) and is_binary(public_key_id) do
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
        {:error, reason}

      {:ok, env} ->
        if success?(env.status) do
          :ok
        else
          msg = "POST request to #{opts[:url]} failed (#{env.status})"
          Logger.error(msg)
          {:error, msg}
        end
    end
  end

  @doc """
  Sends concurrent POST requests. Returns an error if any of the
  requests had an error.
  """
  def batch_deliver(%__MODULE__{} = transport, body, recipients) when is_list(recipients) do
    # TODO async Task optimization
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

  def generate_rsa_pem do
    key = :public_key.generate_key({:rsa, 2048, 65_537})
    entry = :public_key.pem_entry_encode(:RSAPrivateKey, key)
    pem = :public_key.pem_encode([entry]) |> String.trim_trailing()

    {:ok, _, public_key} = keys_from_pem(pem)
    public_key_entry = :public_key.pem_entry_encode(:SubjectPublicKeyInfo, public_key)
    public_key_pem = :public_key.pem_encode([public_key_entry]) |> String.trim_trailing()

    {:ok, pem, public_key_pem}
  end

  def keys_from_pem(pem) do
    with [private_key_code] <- :public_key.pem_decode(pem),
         private_key <- :public_key.pem_entry_decode(private_key_code),
         {:RSAPrivateKey, _, modulus, exponent, _, _, _, _, _, _, _} <- private_key do
      {:ok, private_key, {:RSAPublicKey, modulus, exponent}}
    else
      error -> {:error, error}
    end
  end

  @doc """
  Fetch a public key, given a `Plug.Conn` structure.
  """
  def fetch_public_key(%Plug.Conn{} = conn) do
    with %{"keyId" => kid} <- HTTPSignatures.signature_for_conn(conn),
         {:ok, actor_id} <- key_id_to_actor_id(kid),
         {:ok, public_key} <- get_public_key_for_ap_id(actor_id) do
      {:ok, public_key}
    else
      e ->
        {:error, e}
    end
  end

  @doc """
  Refetch a public key, given a `Plug.Conn` structure.
  Called when the initial key supplied failed to validate the signature.
  """
  def refetch_public_key(%Plug.Conn{} = conn) do
    with %{"keyId" => kid} <- HTTPSignatures.signature_for_conn(conn),
         {:ok, actor_id} <- key_id_to_actor_id(kid),
         {:ok, _user} <- make_user_from_ap_id(actor_id),
         {:ok, public_key} <- get_public_key_for_ap_id(actor_id) do
      {:ok, public_key}
    else
      e ->
        {:error, e}
    end
  end

  def make_user_from_ap_id(uri_str) do
    # TODO IMPL
    {:error, "Unimplemented"}
  end

  def key_id_to_actor_id(key_id) do
    uri =
      key_id
      |> URI.parse()
      |> Map.put(:fragment, nil)
      |> remove_suffix(@known_public_key_suffixes)

    maybe_ap_id = URI.to_string(uri)

    case cast_local_ap_id(maybe_ap_id) do
      {:ok, ap_id} ->
        {:ok, ap_id}

      _ ->
        case get_webfinger_ap_id(maybe_ap_id) do
          %{"ap_id" => ap_id} -> {:ok, ap_id}
          _ -> {:error, maybe_ap_id}
        end
    end
  end

  def get_public_key_for_ap_id(uri_str) do
    # TODO IMPL
    {:error, "Unimplemented"}
  end

  def cast_local_ap_id(uri_str) do
    # TODO IMPL
    {:error, "Unimplemented"}
  end

  def get_webfinger_ap_id(uri_str) do
    # TODO IMPL
    {:error, "Unimplemented"}
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
