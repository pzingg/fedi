defmodule FediServer.Accounts do
  @moduledoc """
  A context that defines domain and business logic
  around users and identities.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  import Ecto.Query, warn: false

  require Logger

  alias FediServer.Repo
  alias FediServer.Accounts.Identity
  alias FediServer.Accounts.User
  alias FediServer.Accounts.UserToken

  ## PubSub

  @pubsub FediServer.PubSub

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(user_id))
  end

  def unsubscribe(user_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(user_id))
  end

  def broadcast!(%User{} = user, msg) do
    Phoenix.PubSub.broadcast!(@pubsub, topic(user.id), {__MODULE__, msg})
  end

  defp topic(user_id), do: "user:#{user_id}"

  ## Users

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email) |> Repo.preload(:identities)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by nickname.

  ## Examples

      iex> get_user_by_nickname("foobar")
      %User{}

      iex> get_user_by_nickname("unknown")
      nil

  """
  def get_user_by_nickname(nickname) when is_binary(nickname) do
    Repo.get_by(User, nickname: nickname)
  end

  @doc """
  Gets a user by nickname and password.

  ## Examples

      iex> get_user_by_nickname_and_password("foobar", "correct_password")
      %User{}

      iex> get_user_by_nickname_and_password("foobar", "invalid_password")
      nil

  """
  def get_user_by_nickname_and_password(nickname, password)
      when is_binary(nickname) and is_binary(password) do
    user = Repo.get_by(User, nickname: nickname)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs, set_roles: "admin")
    |> Repo.insert()
  end

  @doc """
  Registers a user from their GitHub information.
  """
  def register_github_user(info, primary_email, emails, token) do
    if user = get_user_by_provider(:github, :email, primary_email) do
      update_provider_token(:github, user, token)
    else
      registration_changeset =
        User.github_registration_changeset(info, primary_email, emails, token)

      insert_or_update_oauth_user(registration_changeset)
    end
  end

  @doc """
  Registers a user from their Mastodon information.
  """
  def register_mastodon_user(info, email, nickname, token) do
    if user = get_user_by_provider(:mastodon, :nickname, nickname) do
      update_provider_token(:mastodon, user, token)
    else
      registration_changeset = User.mastodon_registration_changeset(info, email, nickname, token)
      insert_or_update_oauth_user(registration_changeset)
    end
  end

  def update_provider_token(provider, %User{} = user, new_token) do
    identity =
      Repo.one!(
        from(i in Identity, where: i.user_id == ^user.id and i.provider == ^to_string(provider))
      )

    {:ok, _} =
      identity
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_change(:provider_token, new_token)
      |> Repo.update()

    {:ok, Repo.preload(user, :identities, force: true)}
  end

  def insert_or_update_oauth_user(registration_changeset) do
    case Repo.insert(registration_changeset) do
      {:ok, user} ->
        {:ok, user}

      {:error, changeset} ->
        case Repo.unique_constraint_error(changeset) do
          nil ->
            {:error, changeset}

          field ->
            attrs = %{
              identities: Ecto.Changeset.get_field(registration_changeset, :identities),
              avatar_url: Ecto.Changeset.get_field(registration_changeset, :avatar_url),
              external_homepage_url:
                Ecto.Changeset.get_field(registration_changeset, :external_homepage_url)
            }

            link_oauth_to_local_user(changeset, field, attrs)
        end
    end
  end

  def link_oauth_to_local_user(changeset, key_field, attrs) do
    value = Ecto.Changeset.get_field(changeset, key_field)
    query = from(u in User, where: field(u, ^key_field) == ^value, preload: [:identities])
    user = Repo.one(query)

    if user do
      Logger.error("link_oauth_to_local_user #{key_field} #{value}")

      user
      |> User.oauth_link_changeset(attrs)
      |> Repo.update()
    else
      {:error, changeset}
    end
  end

  def get_user_by_provider(provider, :email, email) when provider in [:github, :fedi_server] do
    query =
      from(u in User,
        join: i in assoc(u, :identities),
        where:
          i.provider == ^to_string(provider) and
            fragment("lower(?)", u.email) == ^String.downcase(email)
      )

    Repo.one(query)
  end

  def get_user_by_provider(provider, :nickname, nickname)
      when provider in [:mastodon, :fedi_server] do
    query =
      from(u in User,
        join: i in assoc(u, :identities),
        where:
          i.provider == ^to_string(provider) and
            fragment("lower(?)", u.nickname) == ^String.downcase(nickname)
      )

    Repo.one(query)
  end

  @doc """
  Updates just the `:last_login_at` member of the user.
  """
  def update_last_login(%User{} = user) do
    User.login_changeset(user) |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end
end
