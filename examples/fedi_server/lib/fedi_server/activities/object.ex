defmodule FediServer.Activities.Object do
  use Ecto.Schema

  use Arbor.Tree,
    primary_key_type: :string,
    primary_key: :ap_id,
    foreign_key_type: :string,
    foreign_key: :in_reply_to_id

  import Ecto.Changeset
  import Ecto.Query, only: [order_by: 2, limit: 2]
  alias FediServer.Repo

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: false}
  @foreign_key_type :string
  schema "objects" do
    field(:ap_id, :string)
    field(:type, :string)
    field(:actor, :string)
    field(:local?, :boolean)
    field(:public?, :boolean)
    field(:data, :map)

    belongs_to(:in_reply_to, __MODULE__, references: :ap_id)
    belongs_to(:reblog_of, __MODULE__, references: :ap_id)

    has_many(:direct_recipients, {"objects_recipients", FediServer.Activities.Recipient},
      foreign_key: :assoc_id,
      where: [type: :direct],
      on_replace: :delete_if_exists
    )

    has_many(:following_recipients, {"objects_recipients", FediServer.Activities.Recipient},
      foreign_key: :assoc_id,
      where: [type: :following],
      on_replace: :delete_if_exists
    )

    timestamps()
  end

  def conversation(%__MODULE__{} = object) do
    object
    |> __MODULE__.ancestors()
    |> order_by(:inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Returns a 2-tuple. The first element are the self-replies
  and the second are replies by others.
  """
  def replies(%__MODULE__{actor: actor} = object) do
    object
    |> __MODULE__.descendants()
    |> order_by(:inserted_at)
    |> Repo.all()
    |> Enum.split_with(fn %{actor: reply_actor} -> actor == reply_actor end)
  end

  def changeset(%__MODULE__{} = object, attrs \\ %{}) do
    object
    |> cast(attrs, [
      :ap_id,
      :in_reply_to_id,
      :reblog_of_id,
      :type,
      :actor,
      :local?,
      :public?,
      :data
    ])
    |> cast_assoc(:direct_recipients)
    |> cast_assoc(:following_recipients)
    |> validate_required([:ap_id, :type, :actor, :local?, :public?, :data])
    |> unique_constraint(:ap_id)
  end
end
