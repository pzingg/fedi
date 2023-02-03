defmodule FediServer.Repo.Migrations.AddBlockedAccounts do
  use Ecto.Migration

  def change do
    create table(:blocked_accounts, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :ap_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create_index(:blocked_accounts, [:user_id, :ap_id], unique: true)
  end
end
