defmodule FediServer.Activities.Recipient do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  schema "abstract table: recipients" do
    # This will be used by associations on each "concrete" table,
    # :activities_recipients and :objects_recipients:
    field(:assoc_id, Ecto.ULID)
    field(:type, Ecto.Enum, values: [:direct, :following])
    field(:address, :string)

    timestamps(updated_at: false)
  end

  def changeset(%__MODULE__{} = recipient, attrs \\ %{}) do
    recipient
    |> cast(attrs, [:address, :type])
    |> validate_required([:address, :type])
  end
end
