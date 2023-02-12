defmodule FediServer.Repo.Migrations.AddUserObjects do
  use Ecto.Migration

  def change do
    create table(:user_objects, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :collection_id, :string, null: false
      add :type, :string, null: false
      add :actor, :string, null: false
      add :object, :string, null: false
      add :object_type, :string
      add :activity, :string
      add :local?, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_objects, [:collection_id, :object], unique: true)
    create index(:user_objects, :collection_id)
    create index(:user_objects, :type)
    create index(:user_objects, :actor)
    create index(:user_objects, :object)
    create index(:user_objects, :activity)
    create index(:user_objects, :local?)
  end
end
