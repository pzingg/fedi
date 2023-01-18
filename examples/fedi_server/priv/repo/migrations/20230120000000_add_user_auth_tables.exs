defmodule FediServer.Repo.Migrations.AddUserAuthTables do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Will be null for remote users
      add :hashed_password, :string
    end

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
