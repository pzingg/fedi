defmodule FediServer.Repo.Migrations.AddObjects do
  use Ecto.Migration

  def change do
    create table(:objects, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :ap_id, :string, null: false
      add :type, :string, null: false
      add :actor, :string, null: false
      add :local?, :boolean, null: false, default: false
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:objects, :ap_id, unique: true)
    create index(:objects, :type)
    create index(:objects, :actor)
    create index(:objects, :local?)
  end
end
