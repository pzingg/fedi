defmodule FediServer.Repo.Migrations.AddObjects do
  use Ecto.Migration

  def change do
    create table(:objects) do
      add :ap_id, :string, null: false
      add :type, :string, null: false
      add :actor, :string, null: false
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
