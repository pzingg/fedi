defmodule FediServerWeb.UserSessionController do
  use FediServerWeb, :controller

  require Logger

  alias FediServer.Accounts
  alias FediServerWeb.UserAuth
  alias FediServerWeb.Oauth.RedirectionController

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    # %{"email" => email, "password" => password} = user_params
    %{"nickname" => nickname, "password" => password} = user_params

    if user = Accounts.get_user_by_nickname_and_password(nickname, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, "new.html", error_message: "Invalid nickname or password")
    end
  end

  def mastodon(conn, _params) do
    render(conn, "mastodon.html", error_message: nil)
  end

  def mastodon_login(conn, _params) do
    render(conn, "mastodon_login.html", error_message: nil)
  end

  def create_mastodon(conn, %{"user" => user_params}) do
    %{"mastodon_server_url" => server_url} = user_params

    uri = URI.parse(server_url)

    server_url =
      if is_nil(uri.scheme) do
        "https://" <> server_url
      else
        server_url
      end

    redirect_uri = Routes.redirection_url(conn, :new, "mastodon")
    client = RedirectionController.mastodon_client(conn)

    case client.create_app("FediServer", server_url, redirect_uri) do
      {:ok, app} ->
        email = Map.get(user_params, "email")
        password = Map.get(user_params, "password")

        if email && password do
          result =
            with {:ok, info} <- client.login(app, email, password),
                 %{info: info, email: email, nickname: nickname, token: token} <- info do
              Accounts.register_mastodon_user(info, email, nickname, token)
            end

          RedirectionController.oauth_authentication_response(conn, "Mastodon", result)
        else
          conn
          |> redirect(external: client.authorize_url(app))
          |> halt()
        end

      {:error, reason} ->
        Logger.error("create_app error #{inspect(reason)}")

        conn
        |> put_flash(:error, "Access to server #{server_url} was refused")
        |> redirect(to: Routes.user_session_path(conn, :new))
        |> halt()
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
