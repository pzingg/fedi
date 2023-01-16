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
    field(:local, :boolean)
    field(:status, :string)

    timestamps()
  end

  def changeset(%__MODULE__{} = mailbox, params \\ %{}) do
    mailbox
    |> cast(params, [:activity_id, :outgoing, :type, :actor, :local, :status])
    |> validate_required([:activity_id, :outgoing, :type, :actor, :local])
    |> unique_constraint([:outgoing, :actor, :activity_id])
  end
end
