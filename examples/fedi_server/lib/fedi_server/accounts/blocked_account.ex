defmodule FediServer.Accounts.BlockedAccount do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  alias FediServer.Accounts.User

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  @foreign_key_type Ecto.ULID
  schema "blocked_accounts" do
    field(:ap_id, :string)
    belongs_to(:user, User)

    timestamps()
  end

  def build_block(%User{} = user, %URI{} = blocked_id) do
    build_block(user, URI.to_string(blocked_id))
  end

  def build_block(%User{id: user_id}, blocked_id) when is_binary(blocked_id) do
    %__MODULE__{user_id: user_id}
    |> cast(%{ap_id: blocked_id}, [:user_id, :ap_id])
    |> validate_required([:user_id, :ap_id])
    |> unique_constraint([:user_id, :ap_id])
  end
end
