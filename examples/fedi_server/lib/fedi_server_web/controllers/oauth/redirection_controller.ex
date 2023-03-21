defmodule FediServerWeb.Oauth.RedirectionController do
  use FediServerWeb, :controller

  require Logger

  alias FediServer.Accounts

  def new(conn, %{"provider" => "github", "state" => state, "code" => code}) do
    client = github_client(conn)

    result =
      with {:ok, info} <- client.exchange_access_token(state, code),
           %{info: info, primary_email: primary_email, emails: emails, token: token} <- info do
        Accounts.register_github_user(info, primary_email, emails, token)
      end

    oauth_authentication_response(conn, "GitHub", result)
  end

  def new(conn, %{"provider" => "mastodon", "state" => state, "code" => code}) do
    client = mastodon_client(conn)

    result =
      with {:ok, info} <- client.exchange_access_token(state, code),
           %{info: info, email: email, nickname: nickname, token: token} <- info do
        Accounts.register_mastodon_user(info, email, nickname, token)
      end

    oauth_authentication_response(conn, "Mastodon", result)
  end

  def new(conn, %{"provider" => "fedi_server", "state" => state, "code" => code}) do
    conn
    |> render("oob_code.html", state: state, code: code)
  end

  def new(conn, %{"error" => error, "provider" => provider}) do
    Logger.error("Oauth2 #{provider} redirect error #{error}")
    redirect(conn, to: "/")
  end

  def sign_out(conn, _) do
    FediServerWeb.UserAuth.log_out_user(conn)
  end

  def oauth_authentication_response(conn, _provider, {:ok, user}) do
    conn
    |> put_flash(:info, "Welcome #{user.email}")
    |> FediServerWeb.UserAuth.log_in_user(user)
  end

  def oauth_authentication_response(conn, provider, {:error, %Ecto.Changeset{} = changeset}) do
    Logger.error("Failed #{provider} insert #{inspect(changeset.errors)}")

    conn
    |> put_flash(
      :error,
      "We were unable to fetch the necessary information from your #{provider} account"
    )
    |> redirect(to: "/")
  end

  def oauth_authentication_response(conn, provider, {:error, reason}) do
    Logger.error("Failed #{provider} exchange #{inspect(reason)}")

    conn
    |> put_flash(:error, "We were unable to contact #{provider}. Please try again later.")
    |> redirect(to: "/")
  end

  def github_client(conn) do
    conn.assigns[:github_client] || FediServer.Oauth.Github
  end

  def mastodon_client(conn) do
    conn.assigns[:mastodon_client] || FediServer.Oauth.Mastodon
  end
end
