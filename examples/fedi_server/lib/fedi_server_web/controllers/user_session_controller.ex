defmodule FediServerWeb.UserSessionController do
  use FediServerWeb, :controller

  alias FediServer.Accounts
  alias FediServerWeb.UserAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"user" => user_params}) do
    # %{"email" => email, "password" => password} = user_params
    %{"nickname" => nickname, "password" => password} = user_params

    if user = Accounts.get_user_by_nickname_and_password(nickname, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, "new.html", error_message: "Invalid nickname or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
