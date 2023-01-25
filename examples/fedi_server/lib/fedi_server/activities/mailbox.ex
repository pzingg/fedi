defmodule FediServer.Activities.Mailbox do
  use Ecto.Schema
  import Ecto.Changeset

  # :outgoing is true for Outbox, false for Inbox
  # :activity_id is the ap_id (IRI) for the Activity
  # :type is type of the Activity
  # :status is "new", "pending", "processed", "deleted"
  @timestamps_opts [type: :utc_datetime]
  schema "mailboxes" do
    field(:activity_id, :string)
    field(:outgoing, :boolean)
    field(:type, :string)
    field(:actor, :string)
    field(:object, :string)
    field(:visibility, Ecto.Enum, values: [:public, :unlisted, :followers_only, :direct])
    field(:local?, :boolean)
    field(:status, :string)

    timestamps()
  end

  # :public -> "Public - sent to followers and visible on the homepage"
  # :unlisted -> "Unlisted - like public, but hidden from the homepage"
  # :followers_only -> "Followers only"
  # :direct -> "Direct - only visible for mentioned actors"

  def changeset(%__MODULE__{} = mailbox, attrs \\ %{}) do
    mailbox
    |> cast(attrs, [
      :activity_id,
      :outgoing,
      :type,
      :actor,
      :object,
      :visibility,
      :local?,
      :status
    ])
    |> validate_required([:activity_id, :outgoing, :type, :actor, :object, :visibility, :local?])
    |> unique_constraint([:outgoing, :actor, :activity_id])
  end
end
