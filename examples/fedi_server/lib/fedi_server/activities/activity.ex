defmodule FediServer.Activities.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: false}
  schema "activities" do
    field(:ap_id, :string)
    field(:type, :string)
    field(:actor, :string)
    field(:object, :string)
    field(:local?, :boolean)
    field(:public?, :boolean)
    field(:data, :map)

    has_many(:direct_recipients, {"activities_recipients", FediServer.Activities.Recipient},
      foreign_key: :assoc_id,
      where: [type: :direct],
      on_replace: :delete_if_exists
    )

    has_many(:following_recipients, {"activities_recipients", FediServer.Activities.Recipient},
      foreign_key: :assoc_id,
      where: [type: :following],
      on_replace: :delete_if_exists
    )

    timestamps()
  end

  def changeset(%__MODULE__{} = activity, attrs \\ %{}) do
    activity
    |> cast(attrs, [:ap_id, :type, :actor, :object, :local?, :public?, :data])
    |> cast_assoc(:direct_recipients)
    |> cast_assoc(:following_recipients)
    |> validate_required([:ap_id, :type, :actor, :public?, :data])
    |> unique_constraint(:ap_id)
  end
end
