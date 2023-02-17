defmodule FediServer.Repo.Migrations.AddRecipients do
  use Ecto.Migration

  def change do
    create table(:activities_recipients, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true

      add :assoc_id, references(:activities, type: :binary_id, on_delete: :delete_all),
        null: false

      add :type, :string, null: false, default: "direct"
      add :address, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:activities_recipients, :type)
    create index(:activities_recipients, :address)

    create table(:objects_recipients, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :assoc_id, references(:objects, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false, default: "direct"
      add :address, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:objects_recipients, :type)
    create index(:objects_recipients, :address)

    alter table(:activities) do
      add :public?, :boolean, null: false, default: false
      add :listed?, :boolean, null: false, default: false
    end

    create index(:activities, :public?)
    create index(:activities, :listed?)

    alter table(:objects) do
      add :public?, :boolean, null: false, default: false
      add :listed?, :boolean, null: false, default: false
    end

    create index(:objects, :public?)
    create index(:objects, :listed?)
  end
end
