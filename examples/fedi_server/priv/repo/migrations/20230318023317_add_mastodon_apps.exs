defmodule FediServer.Repo.Migrations.AddMastodonApps do
  use Ecto.Migration

  def change do
    create table(:mastodon_apps, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :server_url, :string, null: false
      add :client_name, :string, null: false
      add :scopes, :string, null: false
      add :redirect_uris, :string, null: false
      add :client_id, :string, null: false
      add :client_secret, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:mastodon_apps, [:server_url], unique: true)
  end
end
