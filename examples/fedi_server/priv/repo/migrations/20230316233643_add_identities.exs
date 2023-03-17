defmodule FediServer.Repo.Migrations.AddIdentities do
  use Ecto.Migration

  def change do
    create table(:identities, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :provider, :string, null: false
      add :provider_token, :string, null: false
      add :provider_login, :string, null: false
      add :provider_email, :string, null: false
      add :provider_id, :string, null: false
      add :provider_meta, :map, default: "{}", null: false

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    alter table(:users) do
      add :avatar_url, :string
      add :external_homepage_url, :string
    end

    create index(:identities, [:user_id])
    create index(:identities, [:provider])
    create unique_index(:identities, [:user_id, :provider])
  end
end
