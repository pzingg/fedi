defmodule FediServer.Repo.Migrations.AddUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;"

    create table(:users, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :ap_id, :string, null: false
      add :name, :string, null: false
      add :nickname, :citext, null: false
      add :email, :citext, null: false
      add :inbox, :string, null: false
      add :local, :boolean, null: false, default: true
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
