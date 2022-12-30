defmodule FediServer.Activities.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  alias FediServer.Activities.Inbox

  schema "activities" do
    field :ap_id, :string
    field :type, :string
    field :actor_id, :string
    field :data, :map
    belongs_to :inbox, Inbox
  end

  def changeset(inbox, params \\ %{}) do
    inbox
    |> cast(params, [:ap_id, :type, :actor_id, :data])
    |> cast_assoc(:inbox)
  end
end
