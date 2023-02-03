defmodule FediServer.Accounts.BlockedAccount do
  use Ecto.Schema

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

  def build_block(%User{id: user_id}, blocked_id) when is_binary(blocked_id) do
    %__MODULE__{ap_id: blocked_id, user_id: user_id}
  end
end
