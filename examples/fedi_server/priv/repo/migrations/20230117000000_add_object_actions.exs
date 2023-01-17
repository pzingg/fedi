defmodule FediServer.Repo.Migrations.AddObjectActions do
  use Ecto.Migration

  def change do
    create table(:object_actions, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :type, :string, null: false
      add :actor, :string, null: false
      add :object, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:object_actions, [:type, :actor, :object], unique: true)
  end
end
