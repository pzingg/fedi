defmodule FediServerWeb.AppsController do
  use FediServerWeb, :controller

  require Logger

  alias FediServer.Accounts.User
  alias FediServer.Oauth

  @app_types %{
    user_id: :string,
    name: :string,
    redirect_uris: :string,
    scopes: :string,
    website: :string
  }
  @app_fields Map.keys(@app_types)

  def new(conn, _params) do
    default_app = %{
      user_id: current_user_id(conn),
      redirect_uris: Routes.redirection_url(conn, :new, "fedi_server"),
      scopes: "read write follow push"
    }

    changeset = app_changeset(default_app)
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"app" => app_params}) do
    changeset = app_changeset(%{user_id: current_user_id(conn)}, app_params)
    changeset = %Ecto.Changeset{changeset | action: :insert}

    if changeset.valid? do
      client_id = SecureRandom.uuid()
      client_secret = SecureRandom.hex(64)
      name = Ecto.Changeset.get_change(changeset, :name)
      {redirect_uris, _} = evaluate_redirect_uris(changeset)
      {scopes, _} = evaluate_scopes(changeset)
      scopes = Enum.map(scopes, fn name -> %{name: name} end)

      client_params = %{
        # OAuth client_id
        id: client_id,
        # OAuth client_secret
        secret: client_secret,
        # User id
        user_id: current_user_id(conn),
        # Display name
        name: name,
        # one day
        access_token_ttl: 60 * 60 * 24,
        # one minute
        authorization_code_ttl: 60,
        # one month
        refresh_token_ttl: 60 * 60 * 24 * 30,
        # one day
        id_token_ttl: 60 * 60 * 24,
        # ID token signature algorithm, defaults to "RS512"
        id_token_signature_alg: "RS256",
        # OAuth client redirect_uris
        redirect_uris: redirect_uris,
        # take following authorized_scopes into account (skip public scopes)
        authorize_scope: true,
        # scopes that are authorized using this client
        authorized_scopes: scopes,
        # client supported grant types
        supported_grant_types: [
          "client_credentials",
          "password",
          "authorization_code",
          "refresh_token",
          "implicit",
          "revoke",
          "introspect"
        ],
        # PKCE enabled
        pkce: false,
        # do not require client_secret for refreshing tokens
        public_refresh_token: false,
        # do not require client_secret for revoking tokens
        public_revoke: false
      }

      case Boruta.Ecto.Admin.create_client(client_params) do
        {:ok, _client} ->
          conn
          |> put_flash(:info, "App created successfully")
          |> redirect(to: Routes.apps_path(conn, :show, %{"client_id" => client_id}))
          |> halt()

        {:error, %Ecto.Changeset{} = _client_changeset} ->
          Logger.error("App insert failed on changeset")
          # TODO: See if it was a unique constraint error on [:user_id, :name]

          conn
          |> put_flash(:error, "Could not create app")
          |> render("new.html", changeset: changeset)

        {:error, reason} ->
          Logger.error("App insert failed: #{inspect(reason)}")

          conn
          |> put_flash(:error, "Could not create app")
          |> render("new.html", changeset: changeset)
      end
    else
      Logger.error("invalid #{inspect(changeset.errors)}")
      render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"client_id" => client_id}) do
    case Oauth.get_client(client_id) do
      nil ->
        conn
        |> put_flash(:error, "Not found")
        |> redirect(to: Routes.apps_path(conn, :new))
        |> halt()

      client ->
        if client_valid_for_current_user?(conn, client) do
          render(conn, "show.html", app: client, show_secret: true)
        else
          conn
          |> put_flash(:error, "Not a valid app")
          |> redirect(to: Routes.apps_path(conn, :new))
          |> halt()
        end
    end
  end

  def show(conn, _params) do
    clients =
      conn.assigns[:current_user]
      |> FediServer.Oauth.list_clients_for_user()

    case clients do
      [client | _] ->
        render(conn, "show.html", app: client, show_secret: false)

      _ ->
        conn
        |> put_flash(:error, "No apps")
        |> redirect(to: Routes.apps_path(conn, :new))
        |> halt()
    end
  end

  def app_changeset(app, params \\ %{}) do
    {app, @app_types}
    |> Ecto.Changeset.cast(params, @app_fields)
    |> Ecto.Changeset.validate_required([:user_id, :name])
    |> validate_redirect_uris()
    |> validate_scopes()
  end

  defp current_user_id(conn) do
    case conn.assigns[:current_user] do
      %User{id: id} -> to_string(id)
      _ -> "ANONYMOUS"
    end
  end

  defp client_valid_for_current_user?(conn, client) do
    client.user_id == current_user_id(conn)
  end

  defp validate_redirect_uris(changeset) do
    changeset = Ecto.Changeset.validate_required(changeset, :redirect_uris)

    case evaluate_redirect_uris(changeset) do
      {_uris, [{:error, message} | _]} ->
        Ecto.Changeset.add_error(changeset, :redirect_uris, message)

      {_uris, []} ->
        changeset
    end
  end

  defp validate_scopes(changeset) do
    changeset = Ecto.Changeset.validate_required(changeset, :scopes)

    case evaluate_scopes(changeset) do
      {_uris, [{:error, message} | _]} -> Ecto.Changeset.add_error(changeset, :scopes, message)
      {_uris, []} -> changeset
    end
  end

  defp evaluate_redirect_uris(changeset) do
    Ecto.Changeset.get_change(changeset, :redirect_uris, "")
    |> String.split(~r/\s+/)
    |> Enum.map(&validate_uri/1)
    |> Enum.split_with(fn
      {:error, _} -> false
      _ -> true
    end)
  end

  defp evaluate_scopes(changeset) do
    Ecto.Changeset.get_change(changeset, :scopes, "")
    |> String.split(~r/\s+/)
    |> Enum.map(&validate_scope/1)
    |> Enum.split_with(fn
      {:error, _} -> false
      _ -> true
    end)
  end

  defp validate_uri(s) do
    uri = String.trim(s) |> URI.parse()

    if uri.scheme in ["http", "https"] do
      URI.to_string(uri)
    else
      {:error, "'#{s}' is not an http or https URL"}
    end
  end

  def validate_scope(s) do
    scope = String.trim(s) |> String.downcase()

    if scope in ["read", "write", "follow", "push"] do
      scope
    else
      {:error, "'#{s}' is not a valid scope"}
    end
  end
end
