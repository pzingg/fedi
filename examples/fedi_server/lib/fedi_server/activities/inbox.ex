defmodule FediServer.Activities.Inbox do
  use Ecto.Schema
  import Ecto.Changeset

  alias FediServer.Activities.Activity

  schema "inboxes" do
    field(:iri, :string)
    field(:actor_id, :string)
    has_many(:activities, Activity)
  end

  def changeset(inbox, params \\ %{}) do
    inbox
    |> cast(params, [:iri, :actor_id])
    |> cast_assoc(:activities)
  end
end
