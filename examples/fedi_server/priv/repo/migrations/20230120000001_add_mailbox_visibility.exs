defmodule FediServer.Repo.Migrations.AddMailboxVisibility do
  use Ecto.Migration

  def change do
    alter table(:mailboxes) do
      add :object, :string, null: false
      add :visibility, :string, null: false, default: "direct"
    end

    create_if_not_exists index(:mailboxes, :object)
  end
end
