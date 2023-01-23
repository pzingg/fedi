defmodule FediServer.Repo.Migrations.AddUserCollections do
  use Ecto.Migration

  def change do
    create table(:user_collections) do
      add :collection_id, :string, null: false
      add :type, :string, null: false
      add :actor, :string, null: false
      add :object, :string, null: false
      add :visibility, :string, null: false, default: "direct"

      timestamps(type: :utc_datetime)
    end

    create index(:user_collections, [:collection_id, :object], unique: true)
    create index(:user_collections, :collection_id)
    create index(:user_collections, :type)
    create index(:user_collections, :actor)
    create index(:user_collections, :object)
  end
end
