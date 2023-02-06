defmodule FediServer.Activities.ObjectAction do
  @moduledoc """
  A schema for object likes and shares.
  """

  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  @foreign_key_type Ecto.ULID
  schema "object_actions" do
    field(:type, Ecto.Enum, values: [:like, :share])
    field(:actor, :string)
    field(:activity, :string)
    field(:object, :string)
    field(:local?, :boolean)

    timestamps()
  end

  def changeset(%__MODULE__{} = object_action, attrs \\ %{}) do
    object_action
    |> cast(attrs, [:type, :actor, :activity, :object, :local?])
    |> validate_required([:type, :actor, :activity, :object, :local?])
    |> unique_constraint([:type, :actor, :object])
  end
end
