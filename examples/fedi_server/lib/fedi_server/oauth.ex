defmodule FediServer.Oauth do
  @moduledoc false

  import Ecto.Query

  alias Boruta.Ecto.Client
  alias FediServer.Repo
  alias FediServer.Accounts.User
  alias FediServer.Oauth.MastodonApp

  def get_mastodon_app(server_url) do
    Repo.get_by(MastodonApp, server_url: server_url)
  end

  def get_mastodon_app!(server_url) do
    Repo.get_by!(MastodonApp, server_url: server_url)
  end

  def create_mastodon_app(params) do
    app =
      case get_mastodon_app(params["server_url"]) do
        nil -> %MastodonApp{}
        app -> app
      end

    app
    |> MastodonApp.changeset(params)
    |> Repo.insert_or_update()
  end

  def get_client(client_id) do
    Repo.get(Client, client_id)
  end

  def list_clients_for_user(%User{id: user_id}) do
    list_clients_by_user_id(user_id)
  end

  def list_clients_for_user(_) do
    list_clients_by_user_id("ANONYMOUS")
  end

  defp list_clients_by_user_id(user_id) do
    Client
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
    |> Repo.preload(:authorized_scopes)
  end

  def random_string do
    binary = <<
      System.system_time(:nanosecond)::64,
      :erlang.phash2({node(), self()})::16,
      :erlang.unique_integer()::16
    >>

    binary
    |> Base.url_encode64()
    |> String.replace(["/", "+"], "-")
  end
end
