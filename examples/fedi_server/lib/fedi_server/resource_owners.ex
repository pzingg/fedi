defmodule FediServer.ResourceOwners do
  @behaviour Boruta.Oauth.ResourceOwners

  alias Boruta.Oauth.ResourceOwner
  alias FediServer.Accounts.User
  alias FediServer.Repo

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: username) do
    with %User{id: id, email: email, last_login_at: last_login_at} <-
           Repo.get_by(User, email: username) do
      {:ok, %ResourceOwner{sub: to_string(id), username: email, last_login_at: last_login_at}}
    else
      _ -> {:error, "Not found"}
    end
  end

  def get_by(sub: sub) do
    with %User{id: id, email: email, last_login_at: last_login_at} <- Repo.get_by(User, id: sub) do
      {:ok, %ResourceOwner{sub: to_string(id), username: email, last_login_at: last_login_at}}
    else
      _ -> {:error, "Not found"}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def check_password(resource_owner, password) do
    user = Repo.get_by(User, id: resource_owner.sub)

    case User.valid_password?(user, password) do
      true -> :ok
      false -> {:error, "Invalid email or password"}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%ResourceOwner{}), do: []

  @impl Boruta.Oauth.ResourceOwners
  def claims(_resource_owner, _scope), do: %{}
end
