defmodule FediServer.Activities.User do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  alias FediServerWeb.Router.Helpers, as: Routes

  @timestamps_opts [type: :utc_datetime]
  @primary_key {:id, Ecto.ULID, autogenerate: true}
  schema "users" do
    field(:ap_id, :string)
    field(:inbox, :string)
    field(:name, :string)
    field(:nickname, :string)
    field(:local, :boolean)
    field(:email, :string)
    field(:public_key, :string)
    field(:keys, :string)
    field(:data, :map)

    timestamps()
  end

  @doc """
  Use the data from a Fediverse server to
  populate a User struct for a remote user.
  """
  def new_from_masto_data(data) when is_map(data) do
    %__MODULE__{
      ap_id: data["id"],
      inbox: data["inbox"],
      name: data["name"],
      nickname: data["preferredUsername"],
      local: false,
      public_key: get_in(data, ["publicKey", "publicKeyPem"]),
      data: data
    }
  end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, [:ap_id, :inbox, :name, :nickname, :local, :email, :public_key, :data])
    |> validate_required([:ap_id, :inbox, :name, :nickname, :local, :data])
    |> unique_constraint(:ap_id)
    |> unique_constraint(:nickname)
    |> unique_constraint(:email)
    |> put_keys()
    |> put_data()
  end

  defp put_keys(changeset) do
    if get_field(changeset, :local) && is_nil(get_field(changeset, :keys)) do
      {:ok, private_key_pem, public_key_pem} = FediServer.HTTPClient.generate_rsa_pem()

      changeset
      |> put_change(:keys, private_key_pem)
      |> put_change(:public_key, public_key_pem)
    else
      changeset
    end
  end

  def put_data(changeset) do
    case get_field(changeset, :data) do
      %{"id" => ap_id} when is_binary(ap_id) ->
        changeset

      _ ->
        if get_field(changeset, :local) do
          ap_id = get_field(changeset, :ap_id)
          name = get_field(changeset, :name)
          nickname = get_field(changeset, :nickname)
          public_key = get_field(changeset, :public_key)
          put_change(changeset, :data, fediverse_data(ap_id, name, nickname, public_key))
        else
          changeset
        end
    end
  end

  def fediverse_data(ap_id, name, nickname, public_key, opts \\ []) do
    %{
      "id" => ap_id,
      "type" => Keyword.get(opts, :actor_type, "Person"),
      "following" => "#{ap_id}/following",
      "followers" => "#{ap_id}/followers",
      "inbox" => "#{ap_id}/inbox",
      "outbox" => "#{ap_id}/outbox",
      "featured" => "#{ap_id}/collections/featured",
      "preferredUsername" => nickname,
      "name" => name,
      "summary" => Keyword.get(opts, :bio, name),
      "url" => ap_id,
      "manuallyApprovesFollowers" => Keyword.get(opts, :locked?, false),
      "publicKey" => %{
        "id" => "#{ap_id}#main-key",
        "owner" => ap_id,
        "publicKeyPem" => public_key
      },
      "endpoints" => %{
        "sharedInbox" => Routes.inbox_url(FediServerWeb.Endpoint, :get_shared_inbox)
      },
      "discoverable" => Keyword.get(opts, :discoverable?, false)
      # "attachment" => fields,
      # "tag" => emoji_tags,
      # "capabilities" => capabilities,
      # "alsoKnownAs" => Keyword.get(opts, :also_known_as)
    }
  end
end
