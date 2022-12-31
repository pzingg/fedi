defmodule FediServer.Activities.User do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  schema "users" do
    field :ap_id, :string
    field :inbox, :string
    field :name, :string
    field :nickname, :string
    field :email, :string
    field :local, :boolean
    field :data, :map

    timestamps()
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:ap_id, :inbox, :name, :nickname, :email, :local, :data])
    |> validate_required([:ap_id, :inbox, :name, :nickname, :email, :local, :data])
  end
end
