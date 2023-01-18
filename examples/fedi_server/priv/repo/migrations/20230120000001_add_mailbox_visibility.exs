defmodule FediServer.Repo.Migrations.AddMailboxVisibility do
  use Ecto.Migration

  def change do
    alter table(:mailboxes) do
      add :object, :string, null: false
      add :visibility, :string, null: false, default: "direct"
    end
  end
end
