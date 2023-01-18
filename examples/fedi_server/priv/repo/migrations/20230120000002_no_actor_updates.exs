defmodule FediServer.Repo.Migrations.NoActorUpdates do
  use Ecto.Migration

  def up do
    """
    CREATE FUNCTION no_actor_updates() RETURNS trigger
    LANGUAGE plpgsql AS
    $$BEGIN
    IF NEW.actor <> OLD.actor THEN
      RAISE EXCEPTION 'Actor updates not allowed';
    END IF;
    RETURN NEW;
    END;$$
    """
    |> execute()

    """
    CREATE TRIGGER no_actor_updates
    BEFORE UPDATE ON objects
    FOR EACH ROW EXECUTE PROCEDURE no_actor_updates()
    """
    |> execute()
  end

  def down do
    execute "DELETE TRIGGER no_actor_updates"
  end
end
