defmodule FediServer.Repo.Migrations.AddUserPreferences do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :on_follow, :string, null: false, default: "do_nothing"
    end
  end
end
