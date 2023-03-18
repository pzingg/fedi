defmodule FediServer.Oauth do
  @moduledoc false

  alias FediServer.Repo
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
