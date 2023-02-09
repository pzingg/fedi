defmodule FediServer.Repo.Migrations.AddMailboxes do
  use Ecto.Migration

  def change do
    create table(:mailboxes) do
      add :activity_id, :string, null: false
      add :outgoing, :boolean, null: false, default: false
      add :type, :string, null: false
      add :actor, :string, null: false
      add :object, :string
      add :local?, :boolean, null: false, default: false
      add :visibility, :string, null: false, default: "direct"
      add :status, :string, null: false, default: "new"

      timestamps(type: :utc_datetime)
    end

    create index(:mailboxes, [:outgoing, :actor, :activity_id], unique: true)
    create index(:mailboxes, :activity_id)
    create index(:mailboxes, :outgoing)
    create index(:mailboxes, :type)
    create index(:mailboxes, :actor)
    create index(:mailboxes, :object)
    create index(:mailboxes, :local?)
    create index(:mailboxes, :status)
  end
end
