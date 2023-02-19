defmodule FediServer.Repo.Migrations.AddActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :ap_id, :string, null: false
      add :type, :string, null: false
      add :actor, :string, null: false
      add :object, :string
      add :local?, :boolean, null: false, default: true
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:activities, :ap_id, unique: true)
    create index(:activities, :type)
    create index(:activities, :actor)
    create index(:activities, :object)
    create index(:activities, :local?)
  end
end
