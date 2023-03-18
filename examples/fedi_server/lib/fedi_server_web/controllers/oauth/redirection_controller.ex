defmodule FediServerWeb.Oauth.RedirectionController do
  use FediServerWeb, :controller

  require Logger

  alias FediServer.Accounts

  def new(conn, %{"provider" => "github", "state" => state, "code" => code}) do
    client = github_client(conn)

    with {:ok, info} <- client.exchange_access_token(state, code),
         %{info: info, primary_email: primary_email, emails: emails, token: token} <- info,
         {:ok, user} <- Accounts.register_github_user(info, primary_email, emails, token) do
      conn
      |> put_flash(:info, "Welcome #{user.email}")
      |> FediServerWeb.UserAuth.log_in_user(user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed GitHub insert #{inspect(changeset.errors)}")

        conn
        |> put_flash(
          :error,
          "We were unable to fetch the necessary information from your GithHub account"
        )
        |> redirect(to: "/")

      {:error, reason} ->
        Logger.error("Failed GitHub exchange #{inspect(reason)}")

        conn
        |> put_flash(:error, "We were unable to contact GitHub. Please try again later.")
        |> redirect(to: "/")
    end
  end

  def new(conn, %{"provider" => "mastodon", "state" => state, "code" => code}) do
    client = mastodon_client(conn)

    with {:ok, info} <- client.exchange_access_token(state, code),
         %{info: info, email: email, nickname: nickname, token: token} <- info,
         {:ok, user} <- Accounts.register_mastodon_user(info, email, nickname, token) do
      conn
      |> put_flash(:info, "Welcome #{nickname}")
      |> FediServerWeb.UserAuth.log_in_user(user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Failed Mastodon insert #{inspect(changeset.errors)}")

        conn
        |> put_flash(
          :error,
          "We were unable to fetch the necessary information from your Mastodon account"
        )
        |> redirect(to: "/")

      {:error, reason} ->
        Logger.error("Failed Mastodon exchange #{inspect(reason)}")

        conn
        |> put_flash(:error, "We were unable to contact Mastodon. Please try again later.")
        |> redirect(to: "/")
    end
  end

  def new(conn, %{"error" => error, "provider" => provider}) do
    Logger.error("Oauth2 #{provider} redirect error #{error}")
    redirect(conn, to: "/")
  end

  def sign_out(conn, _) do
    FediServerWeb.UserAuth.log_out_user(conn)
  end

  defp github_client(conn) do
    conn.assigns[:github_client] || FediServer.Oauth.Github
  end

  defp mastodon_client(conn) do
    conn.assigns[:mastodon_client] || FediServer.Oauth.Mastodon
  end
end
