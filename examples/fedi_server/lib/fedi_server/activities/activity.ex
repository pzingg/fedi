defmodule FediServer.Activities.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: false}
  schema "activities" do
    field :ap_id, :string
    field :type, :string
    field :actor, :string
    field :local, :boolean
    field :recipients, {:array, :string}
    field :data, :map

    timestamps()
  end

  def changeset(activity, params \\ %{}) do
    activity
    |> cast(params, [:ap_id, :type, :actor, :local, :recipients, :data])
    |> validate_required([:ap_id, :type, :actor, :data])
  end
end
