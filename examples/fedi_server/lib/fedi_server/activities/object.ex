defmodule FediServer.Activities.Object do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: false}
  schema "objects" do
    field :ap_id, :string
    field :type, :string
    field :actor, :string
    field :local, :boolean
    field :data, :map

    timestamps()
  end

  def changeset(%__MODULE__{} = object, params \\ %{}) do
    object
    |> cast(params, [:ap_id, :type, :actor, :local, :data])
    |> validate_required([:ap_id, :type, :actor, :local, :data])
    |> unique_constraint(:ap_id)
  end
end
