defmodule FediServer.Repo.Migrations.AddUserUsers do
  use Ecto.Migration

  def change do
    create table(:user_users, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :type, :string, null: false
      add :actor, :string, null: false
      add :relation, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_users, [:type, :actor, :relation], unique: true)
    create index(:user_users, :type)
    create index(:user_users, :actor)
    create index(:user_users, :relation)
  end
end
