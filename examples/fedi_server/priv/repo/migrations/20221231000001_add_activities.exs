defmodule FediServer.Repo.Migrations.AddActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :ap_id, :string, null: false
      add :type, :string, null: false
      add :actor, :string, null: false
      add :local, :boolean, null: false, default: true
      add :recipients, {:array, :string}, null: false, default: []
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
