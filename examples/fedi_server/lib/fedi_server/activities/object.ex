defmodule FediServer.Activities.Object do
  use Ecto.Schema

  use Arbor.Tree,
    primary_key_type: :string,
    primary_key: :ap_id,
    foreign_key_type: :string,
    foreign_key: :in_reply_to_id

  import Ecto.Changeset

  alias FediServer.Activities.ChangesetValidators

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

  def changeset(%__MODULE__{} = object, attrs \\ %{}, opts \\ []) do
    object
    |> cast(attrs, [
      :id,
      :ap_id,
      :in_reply_to_id,
      :reblog_of_id,
      :type,
      :actor,
      :local?,
      :public?,
      :data,
      :inserted_at,
      :updated_at
    ])
    |> cast_assoc(:direct_recipients)
    |> cast_assoc(:following_recipients)
    |> validate_required([:ap_id, :type, :actor, :local?, :data])
    |> unique_constraint(:ap_id)
    |> ChangesetValidators.validate_id()
    |> ChangesetValidators.maybe_set_public()
    |> maybe_set_published(opts)
  end

  def maybe_set_published(changeset, opts) do
    data = get_field(changeset, :data)
    dt_property = Keyword.get(opts, :dt_property, "published")

    if !is_map(data) do
      changeset
    else
      # TODO handle "Tombstone" type
      if Enum.member?(["published", "updated", "deleted"], dt_property) do
        if Map.has_key?(data, dt_property) do
          changeset
        else
          now = DateTime.utc_now() |> DateTime.truncate(:second)
          data = Map.put(data, dt_property, Timex.format!(now, "{RFC3339z}"))

          case dt_property do
            "published" ->
              changeset
              |> put_change(:data, data)
              |> put_change(:inserted_at, now)
              |> put_change(:updated_at, now)

            _ ->
              changeset
              |> put_change(:data, data)
              |> put_change(:updated_at, now)
          end
        end
      else
        changeset
      end
    end
  end
end
