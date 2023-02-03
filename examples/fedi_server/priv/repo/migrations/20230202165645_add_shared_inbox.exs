defmodule FediServer.Repo.Migrations.AddSharedInbox do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :shared_inbox, :string
      remove :public_key
    end
  end
end
