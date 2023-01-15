defmodule FediServer.Repo.Migrations.AddFollowingRelationships do
  use Ecto.Migration

  def change do
    create table(:following_relationships, primary_key: false) do
      add :id, :binary_id, null: false, primary_key: true
      add :state, :string, null: false, default: "pending"
      add :follower_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :following_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:following_relationships, [:follower_id, :following_id], unique: true)
    create index(:following_relationships, :follower_id)
    create index(:following_relationships, :state)
  end
end
