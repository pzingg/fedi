defmodule FediServer.Activities.Object do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]
  schema "objects" do
    field :ap_id, :string
    field :type, :string
    field :actor, :string
    field :data, :map

    timestamps()
  end

  def changeset(object, params \\ %{}) do
    object
    |> cast(params, [:ap_id, :type, :actor, :data])
    |> validate_required([:ap_id, :type, :actor, :data])
  end
end
