defmodule FediServer.Activities.UserCollection do
  use Ecto.Schema
  import Ecto.Changeset

  alias FediServer.Activities

  # :activity_id is the ap_id (IRI) for the Activity
  # :type is type of the Activity
  @timestamps_opts [type: :utc_datetime]
  schema "user_collections" do
    field(:collection_id, :string)
    field(:type, :string)
    field(:actor, :string)
    field(:object, :string)
    field(:visibility, Ecto.Enum, values: [:public, :unlisted, :followers_only, :direct])

    timestamps()
  end

  def changeset(%__MODULE__{} = mailbox, attrs \\ %{}) do
    mailbox
    |> cast(attrs, [:collection_id, :type, :actor, :object, :visibility])
    |> validate_required([:collection_id, :type, :actor, :object])
    |> unique_constraint([:collection_id, :object])
  end
end
