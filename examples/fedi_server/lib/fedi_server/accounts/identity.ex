defmodule FediServer.Accounts.Identity do
  use Ecto.Schema
  import Ecto.Changeset

  alias FediServer.Accounts.User

  @derive {Inspect, except: [:provider_token, :provider_meta]}
  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  @foreign_key_type Ecto.ULID
  schema "identities" do
    field(:provider, :string)
    field(:provider_token, :string)
    field(:provider_email, :string)
    field(:provider_login, :string)
    field(:provider_name, :string, virtual: true)
    field(:provider_id, :string)
    field(:provider_meta, :map)

    belongs_to(:user, User)

    timestamps()
  end

  def changeset(provider, meta, params) do
    %__MODULE__{provider: provider, provider_meta: meta}
    |> cast(params, [
      :provider_token,
      :provider_email,
      :provider_login,
      :provider_name,
      :provider_id
    ])
    |> validate_required([:provider_token, :provider_email, :provider_name, :provider_id])
    |> validate_length(:provider_meta, max: 10_000)
  end
end
