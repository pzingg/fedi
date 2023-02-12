defmodule FediServer.Activities.UserObject do
  @moduledoc """
  A schema for object likes and shares.
  """

  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  @foreign_key_type Ecto.ULID
  schema "user_objects" do
    field(:collection_id, :string)
    field(:type, Ecto.Enum, values: [:like, :share, :favourite, :bookmark, :custom])
    field(:actor, :string)
    field(:object, :string)
    field(:object_type, :string)
    field(:activity, :string)
    field(:local?, :boolean)

    timestamps()
  end

  def changeset(%__MODULE__{} = user_object, attrs \\ %{}) do
    user_object
    |> cast(attrs, [:collection_id, :type, :actor, :object, :object_type, :activity, :local?])
    |> validate_required([:collection_id, :type, :actor, :object, :object_type, :local?])
    |> unique_constraint([:collection_id, :object])
  end
end
