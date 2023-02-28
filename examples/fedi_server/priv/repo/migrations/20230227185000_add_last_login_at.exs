defmodule FediServer.Repo.Migrations.AddLastLoginAt do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_login_at, :utc_datetime
    end

    create index(:users, :last_login_at)
  end
end
