defmodule FediServer.Oauth.MastodonApp do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  schema "mastodon_apps" do
    field(:server_url, :string)
    field(:client_name, :string)
    field(:scopes, :string)
    field(:redirect_uris, :string)
    field(:client_id, :string)
    field(:client_secret, :string)

    timestamps()
  end

  def changeset(%__MODULE__{} = mastodon_app, params) do
    mastodon_app
    |> cast(params, [
      :server_url,
      :client_name,
      :scopes,
      :redirect_uris,
      :client_id,
      :client_secret
    ])
    |> validate_required([
      :server_url,
      :client_name,
      :scopes,
      :redirect_uris,
      :client_id,
      :client_secret
    ])
    |> unsafe_validate_unique(:server_url, FediServer.Repo)
    |> unique_constraint(:server_url)
  end
end
