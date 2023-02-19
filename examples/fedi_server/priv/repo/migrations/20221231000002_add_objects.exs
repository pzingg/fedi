defmodule FediServer.Repo.Migrations.AddObjects do
  use Ecto.Migration

  def change do
    create table(:objects, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :reblog_of_id, :string
      add :in_reply_to_id, :string
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

    flush()

    # Unique constraint must be created first
    alter table(:objects) do
      modify :reblog_of_id, references(:objects, column: :ap_id, type: :string)
      modify :in_reply_to_id, references(:objects, column: :ap_id, type: :string)
    end
  end
end
