defmodule FediServer.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  alias Fedi.Streams.Utils
  alias FediServer.Accounts.Identity
  alias FediServerWeb.Router.Helpers, as: Routes

  @derive {Phoenix.Param, key: :nickname}
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
    field(:password_confirmation, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:shared_inbox, :string)
    field(:last_login_at, :utc_datetime)

    field(:on_follow, Ecto.Enum,
      values: [:do_nothing, :automatically_accept, :automatically_reject]
    )

    field(:avatar_url, :string)
    field(:external_homepage_url, :string)
    field(:keys, :string)
    field(:data, :map)

    has_many(:identities, Identity)

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
    Fedi.Application.endpoint_url()
    |> Utils.base_uri(shared_inbox_path())
    |> URI.to_string()
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%__MODULE__{local?: true, hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def registration_changeset(%__MODULE__{} = user, attrs, opts \\ []) do
    %__MODULE__{user | local?: true}
    |> cast(attrs, [:name, :nickname, :email, :password, :password_confirmation])
    |> validate_required([:name])
    |> validate_nickname()
    |> put_ap_id_and_inbox()
    |> validate_email()
    |> validate_password(opts)
    |> maybe_put_shared_inbox()
    |> maybe_put_keys()
    |> maybe_put_data()
  end

  def login_changeset(%__MODULE__{} = user) do
    attrs = %{last_login_at: DateTime.utc_now()}

    user
    |> cast(attrs, [:last_login_at])
    |> validate_required(:last_login_at)
  end

  @doc """
  A user changeset for github registration.
  """
  def github_registration_changeset(info, primary_email, emails, token) do
    %{"login" => username, "avatar_url" => avatar_url, "html_url" => external_homepage_url} = info

    identity_changeset =
      Identity.github_registration_changeset(info, primary_email, emails, token)

    if identity_changeset.valid? do
      params = %{
        "nickname" => username,
        "email" => primary_email,
        "name" => get_change(identity_changeset, :provider_name),
        "avatar_url" => avatar_url,
        "external_homepage_url" => external_homepage_url
      }

      %__MODULE__{local?: true}
      |> cast(params, [:name, :nickname, :email, :avatar_url, :external_homepage_url])
      |> validate_required([:name])
      |> validate_nickname()
      |> put_ap_id_and_inbox()
      |> validate_email()
      |> maybe_put_shared_inbox()
      |> maybe_put_keys()
      |> maybe_put_data()
      |> put_assoc(:identities, [identity_changeset])
    else
      %__MODULE__{local?: true}
      |> change()
      |> Map.put(:valid?, false)
      |> put_assoc(:identities, [identity_changeset])
    end
  end

  def github_link_changeset(%__MODULE__{} = user, info, primary_email, emails, token) do
    %{"avatar_url" => avatar_url, "html_url" => external_homepage_url} = info

    identity_changeset =
      Identity.github_registration_changeset(info, primary_email, emails, token)

    if identity_changeset.valid? do
      params = %{
        "avatar_url" => avatar_url,
        "external_homepage_url" => external_homepage_url
      }

      user
      |> cast(params, [:avatar_url, :external_homepage_url])
      |> maybe_put_data()
      |> put_assoc(:identities, [identity_changeset])
    else
      user
      |> change()
      |> Map.put(:valid?, false)
      |> put_assoc(:identities, [identity_changeset])
    end
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
      :last_login_at,
      :on_follow,
      :data
    ])
    |> validate_required([:ap_id, :inbox, :name, :nickname, :local?, :on_follow, :data])
    |> unique_constraint(:ap_id)
    |> unique_constraint(:nickname)
    |> validate_email()
    |> validate_password()
    |> maybe_put_shared_inbox()
    |> maybe_put_keys()
    |> maybe_put_data()
  end

  defp validate_nickname(changeset) do
    changeset
    |> validate_required([:nickname])
    |> validate_format(:nickname, ~r/^[a-z][-_a-z0-9]+$/,
      message: "must be lowercase alpha and numbers"
    )
    |> validate_length(:nickname, min: 4, max: 20)
  end

  def put_ap_id_and_inbox(changeset) do
    nickname = get_change(changeset, :nickname)

    if get_field(changeset, :local?) && nickname do
      endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()
      ap_id = Utils.base_uri(endpoint_uri, "/users/#{nickname}")
      inbox = Utils.base_uri(endpoint_uri, "/users/#{nickname}/inbox")

      changeset
      |> put_change(:ap_id, URI.to_string(ap_id))
      |> unsafe_validate_unique(:ap_id, FediServer.Repo)
      |> unique_constraint(:ap_id)
      |> put_change(:inbox, URI.to_string(inbox))
      |> unsafe_validate_unique(:inbox, FediServer.Repo)
      |> unique_constraint(:inbox)
    else
      changeset
    end
  end

  defp validate_email(changeset) do
    if get_field(changeset, :local?) do
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)
      |> unsafe_validate_unique(:email, FediServer.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp validate_password(changeset, opts \\ []) do
    if get_field(changeset, :local?) && get_change(changeset, :password) do
      changeset
      |> validate_length(:password, min: 4, max: 80)
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
          email = get_field(changeset, :email)
          keys_pem = get_field(changeset, :keys)

          if ap_id && name && nickname && email && keys_pem do
            public_key_pem =
              case FediServer.HTTPClient.public_key_pem_from_keys(keys_pem) do
                {:ok, pem} ->
                  pem

                {:error, reason} ->
                  Logger.error("Did not decode a public key #{reason}.")
                  nil
              end

            opts =
              case get_field(changeset, :avatar_url) do
                nil -> []
                url -> [avatar_url: url]
              end

            put_change(
              changeset,
              :data,
              fediverse_data(ap_id, name, nickname, email, public_key_pem, opts)
            )
          else
            changeset
          end
        else
          changeset
        end
    end
  end

  @doc """
  Ref: [AP Section 4.1](https://www.w3.org/TR/activitypub/#actor-objects)
  """
  def fediverse_data(ap_id, name, nickname, email, public_key, opts \\ []) do
    user_suffix = "/users/#{nickname}"
    user_url = String.replace_trailing(ap_id, user_suffix, "/@#{nickname}")
    avatar_url = Keyword.get(opts, :avatar_url) || make_gravatar_url(email)

    %{
      "type" => Keyword.get(opts, :actor_type, "Person"),
      "id" => ap_id,
      "url" => user_url,
      "name" => name,
      "preferredUsername" => nickname,
      "summary" => Keyword.get(opts, :bio, name),
      "discoverable" => Keyword.get(opts, :discoverable?, true),
      "manuallyApprovesFollowers" => Keyword.get(opts, :locked?, false),
      "inbox" => "#{ap_id}/inbox",
      "outbox" => "#{ap_id}/outbox",
      "following" => "#{ap_id}/following",
      "followers" => "#{ap_id}/followers",
      "featured" => "#{ap_id}/collections/featured",
      "endpoints" => %{
        "sharedInbox" => shared_inbox_uri()
      },
      "publicKey" => %{
        "id" => "#{ap_id}#main-key",
        "owner" => ap_id,
        "publicKeyPem" => public_key
      },
      "icon" => %{
        "type" => "Image",
        "mediaType" => "image/jpeg",
        "url" => avatar_url
      }
      # "attachment" => fields,
      # "tag" => emoji_tags,
      # "capabilities" => capabilities,
      # "alsoKnownAs" => Keyword.get(opts, :also_known_as)
    }
  end

  def make_gravatar_url(email) do
    email_hash = :crypto.hash(:md5, email) |> Base.encode16() |> String.downcase()
    "https://www.gravatar.com/avatar/#{email_hash}.jpg?s=144&d=mp"
  end
end
