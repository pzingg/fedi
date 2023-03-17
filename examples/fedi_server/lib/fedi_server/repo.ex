defmodule FediServer.Repo do
  use Ecto.Repo,
    otp_app: :fedi_server,
    adapter: Ecto.Adapters.Postgres

  def unique_constraint_error(changeset, field \\ nil)

  def unique_constraint_error(changeset, nil) do
    Enum.find(changeset.errors, fn {_field, {_msg, opts}} ->
      opts[:validation] == :unsafe_unique || opts[:constraint] == :unique
    end)
  end

  def unique_constraint_error(changeset, field) when is_atom(field) do
    case Keyword.get(changeset.errors, field) do
      {_msg, opts} -> opts[:validation] == :unsafe_unique || opts[:constraint] == :unique
      _ -> false
    end
  end
end
