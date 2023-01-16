defmodule FediServer.Activities.FollowingRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  alias FediServer.Activities.User
  alias FediServerWeb.Router.Helpers, as: Routes

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  @foreign_key_type Ecto.ULID
  schema "following_relationships" do
    field(:state, Ecto.Enum, values: [:pending, :accepted, :rejected])

    belongs_to(:follower, User)
    belongs_to(:following, User)

    timestamps()
  end

  def changeset(%__MODULE__{} = following_relationship, attrs) do
    following_relationship
    |> cast(attrs, [:state])
    |> put_assoc(:follower, attrs.follower)
    |> put_assoc(:following, attrs.following)
    |> validate_required([:state, :follower, :following])
    |> unique_constraint(:follower_id,
      name: :following_relationships_follower_id_following_id_index
    )
    |> validate_not_self_relationship()
  end

  def state_changeset(%__MODULE__{} = following_relationship, attrs) do
    following_relationship
    |> cast(attrs, [:state])
    |> validate_required(:state)
  end

  defp validate_not_self_relationship(changeset) do
    changeset
    |> validate_follower_id_following_id_inequality()
    |> validate_following_id_follower_id_inequality()
  end

  defp validate_follower_id_following_id_inequality(changeset) do
    validate_change(changeset, :follower_id, fn _, follower_id ->
      if follower_id == get_field(changeset, :following_id) do
        [source_id: "can't be equal to following_id"]
      else
        []
      end
    end)
  end

  defp validate_following_id_follower_id_inequality(changeset) do
    validate_change(changeset, :following_id, fn _, following_id ->
      if following_id == get_field(changeset, :follower_id) do
        [target_id: "can't be equal to follower_id"]
      else
        []
      end
    end)
  end
end