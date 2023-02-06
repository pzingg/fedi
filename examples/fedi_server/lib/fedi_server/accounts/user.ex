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
    field(:local?, :boolean)
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:shared_inbox, :string)

    field(:on_follow, Ecto.Enum,
      values: [:do_nothing, :automatically_accept, :automatically_reject]
    )

    field(:keys, :string)
    field(:data, :map)

    timestamps()
  end

  @doc """
  Use the data from a Fediverse server to populate a User struct for a remote user.
  """
  def new_remote_user(data) when is_map(data) do
    on_follow =
      case data["manuallyApprovesFollowers"] do
        nil -> :do_nothing
        false -> :automatically_accept
        _ -> :do_nothing
      end

    %__MODULE__{
      ap_id: data["id"],
      inbox: data["inbox"],
      name: data["name"],
      nickname: data["preferredUsername"],
      local?: false,
      keys: get_in(data, ["publicKey", "publicKeyPem"]),
      shared_inbox: get_in(data, ["endpoints", "sharedInbox"]),
      on_follow: on_follow,
      data: data
    }
  end

  def get_public_key(%__MODULE__{keys: pem}) do
    case FediServer.HTTPClient.decode_keys(pem) do
      {:ok, _, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, reason}
    end
  end

  def shared_inbox_path, do: Routes.inbox_path(FediServerWeb.Endpoint, :get_shared_inbox)

  def shared_inbox_uri do
    uri = Fedi.Application.endpoint_url() |> Utils.to_uri()
    %URI{uri | path: shared_inbox_path()}
  end

  def changeset(%__MODULE__{} = user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :ap_id,
      :inbox,
      :name,
      :nickname,
      :local?,
      :email,
      :password,
      :keys,
      :shared_inbox,
      :on_follow,
      :data
    ])
    |> validate_required([:ap_id, :inbox, :name, :nickname, :local?, :on_follow, :data])
    |> unique_constraint(:ap_id)
    |> unique_constraint(:nickname)
    |> unique_constraint(:email)
    |> validate_password()
    |> maybe_put_shared_inbox()
    |> maybe_put_keys()
    |> maybe_put_data()
  end

  defp validate_password(changeset, opts \\ []) do
    if get_field(changeset, :local?) && get_change(changeset, :password) do
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

  defp maybe_put_shared_inbox(changeset) do
    if get_field(changeset, :local?) && is_nil(get_field(changeset, :shared_inbox)) do
      put_change(changeset, :shared_inbox, shared_inbox_uri())
    else
      changeset
    end
  end

  defp maybe_put_keys(changeset) do
    if get_field(changeset, :local?) && is_nil(get_field(changeset, :keys)) do
      {:ok, private_key_pem, _public_key_pem} = FediServer.HTTPClient.generate_rsa_pem()

      changeset
      |> put_change(:keys, private_key_pem)
    else
      changeset
    end
  end

  def maybe_put_data(changeset) do
    case get_field(changeset, :data) do
      %{"id" => ap_id} when is_binary(ap_id) ->
        changeset

      _ ->
        if get_field(changeset, :local?) do
          ap_id = get_field(changeset, :ap_id)
          name = get_field(changeset, :name)
          nickname = get_field(changeset, :nickname)
          keys_pem = get_field(changeset, :keys)

          public_key_pem =
            case FediServer.HTTPClient.public_key_pem_from_keys(keys_pem) do
              {:ok, pem} ->
                pem

              {:error, reason} ->
                Logger.error("Did not decode a public key #{reason}.")
                nil
            end

          put_change(changeset, :data, fediverse_data(ap_id, name, nickname, public_key_pem))
        else
          changeset
        end
    end
  end

  @doc """
  Ref: [AP Section 4.1](https://www.w3.org/TR/activitypub/#actor-objects)
  """
  def fediverse_data(ap_id, name, nickname, public_key, opts \\ []) do
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
        "sharedInbox" => shared_inbox_uri() |> URI.to_string()
      },
      "discoverable" => Keyword.get(opts, :discoverable?, true)
      # "featured" => "#{ap_id}/collections/featured",
      # "icon" => icon,
      # "attachment" => fields,
      # "tag" => emoji_tags,
      # "capabilities" => capabilities,
      # "alsoKnownAs" => Keyword.get(opts, :also_known_as)
    }
  end
end
