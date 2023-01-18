defmodule FediServer.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  alias Fedi.Streams.Utils
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
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:public_key, :string)
    field(:keys, :string)
    field(:data, :map)

    timestamps()
  end

  @doc """
  Use the data from a Fediverse server to populate a User struct for a remote user.
  """
  def new_remote_user(data) when is_map(data) do
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

  def get_public_key(%__MODULE__{public_key: public_key_pem}) do
    FediServer.HTTPClient.public_key_from_pem(public_key_pem)
  end

  def changeset(%__MODULE__{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :ap_id,
      :inbox,
      :name,
      :nickname,
      :local,
      :email,
      :password,
      :public_key,
      :data
    ])
    |> validate_required([:ap_id, :inbox, :name, :nickname, :local, :data])
    |> unique_constraint(:ap_id)
    |> unique_constraint(:nickname)
    |> unique_constraint(:email)
    |> validate_password()
    |> maybe_put_keys()
    |> maybe_put_data()
  end

  defp validate_password(changeset, opts \\ []) do
    if get_field(changeset, :local) && get_change(changeset, :password) do
      changeset
      # |> validate_length(:password, min: 12, max: 80)
      # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
      # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
      # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
      |> maybe_hash_password(opts)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_put_keys(changeset) do
    if get_field(changeset, :local) && is_nil(get_field(changeset, :keys)) do
      {:ok, private_key_pem, public_key_pem} = FediServer.HTTPClient.generate_rsa_pem()

      changeset
      |> put_change(:keys, private_key_pem)
      |> put_change(:public_key, public_key_pem)
    else
      changeset
    end
  end

  def maybe_put_data(changeset) do
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

  @doc """
  Ref: [AP Section 4.1](https://www.w3.org/TR/activitypub/#actor-objects)
  """
  def fediverse_data(ap_id, name, nickname, public_key, opts \\ []) do
    endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()

    shared_inbox_uri = %URI{
      endpoint_uri
      | path: Routes.inbox_path(FediServerWeb.Endpoint, :get_shared_inbox)
    }

    %{
      "id" => ap_id,
      "type" => Keyword.get(opts, :actor_type, "Person"),
      "inbox" => "#{ap_id}/inbox",
      "outbox" => "#{ap_id}/outbox",
      "following" => "#{ap_id}/following",
      "followers" => "#{ap_id}/followers",
      "preferredUsername" => nickname,
      "url" => ap_id,
      "name" => name,
      "summary" => Keyword.get(opts, :bio, name),
      "manuallyApprovesFollowers" => Keyword.get(opts, :locked?, false),
      "publicKey" => %{
        "id" => "#{ap_id}#main-key",
        "owner" => ap_id,
        "publicKeyPem" => public_key
      },
      "endpoints" => %{
        "sharedInbox" => URI.to_string(shared_inbox_uri)
      },
      "discoverable" => Keyword.get(opts, :discoverable?, false)
      # "featured" => "#{ap_id}/collections/featured",
      # "icon" => icon,
      # "attachment" => fields,
      # "tag" => emoji_tags,
      # "capabilities" => capabilities,
      # "alsoKnownAs" => Keyword.get(opts, :also_known_as)
    }
  end
end
