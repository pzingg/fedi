defmodule FediServer.Repo.Migrations.AddMailboxes do
  use Ecto.Migration

  def change do
    create table(:mailboxes) do
      add :activity_id, :binary_id, null: false
      add :outgoing, :boolean, null: false, default: false
      add :type, :string, null: false
      add :owner, :string, null: false
      add :local, :boolean, null: false, default: false
      add :status, :string, null: false, default: "new"

      timestamps(type: :utc_datetime)
    end

    create index(:mailboxes, [:outgoing, :owner, :activity_id], unique: true)
    create index(:mailboxes, :activity_id)
    create index(:mailboxes, :outgoing)
    create index(:mailboxes, :type)
    create index(:mailboxes, :owner)
    create index(:mailboxes, :local)
    create index(:mailboxes, :status)
  end
end
