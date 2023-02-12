defmodule FediServer.Activities.UserUser do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  @foreign_key_type Ecto.ULID
  schema "user_users" do
    field(:type, Ecto.Enum, values: [:follow_request, :follow, :block, :mute])
    field(:actor, :string)
    field(:relation, :string)

    timestamps()
  end

  def changeset(%__MODULE__{} = user_user, attrs \\ %{}) do
    user_user
    |> cast(attrs, [:type, :actor, :relation])
    |> validate_required([:actor, :relation])
    |> unique_constraint(:actor, name: :user_users_type_actor_relation_index)
    |> validate_not_self_relationship()
  end

  defp validate_not_self_relationship(changeset) do
    changeset
    |> validate_actor_relation_inequality()
    |> validate_relation_actor_inequality()
  end

  defp validate_actor_relation_inequality(changeset) do
    validate_change(changeset, :actor, fn _, actor ->
      if actor == get_field(changeset, :relation) do
        [actor: "can't be equal to relation"]
      else
        []
      end
    end)
  end

  defp validate_relation_actor_inequality(changeset) do
    validate_change(changeset, :relation, fn _, relation ->
      if relation == get_field(changeset, :actor) do
        [relation: "can't be equal to actor"]
      else
        []
      end
    end)
  end
end
