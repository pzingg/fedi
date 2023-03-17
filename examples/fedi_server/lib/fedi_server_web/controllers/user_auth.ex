defmodule FediServerWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  require Logger

  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.Scope
  alias Fedi.ActivityPub.Utils, as: APUtils
  alias FediServer.Accounts
  alias FediServer.Accounts.User
  alias FediServerWeb.Router.Helpers, as: Routes

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in UserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_fedi_server_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    _ = Accounts.update_last_login(user)

    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_session(:user_token, token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
    |> halt()
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    user_token && Accounts.delete_session_token(user_token)

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: "/")
    |> halt()
  end

  @doc """
  Authenticates the user by looking into the session
  and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)

    case user_token && Accounts.get_user_by_session_token(user_token) do
      %User{} = user ->
        assign(conn, :current_user, user)

      _ ->
        assign(conn, :current_user, nil)
    end
  end

  defp ensure_user_token(conn) do
    if user_token = get_session(conn, :user_token) do
      {user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if user_token = conn.cookies[@remember_me_cookie] do
        {user_token, put_session(conn, :user_token, user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Check that the :current_user is not nil and is the actor.
  """
  def logged_in_actor?(conn, %URI{} = actor_iri) do
    case conn.assigns[:current_user] do
      %User{ap_id: ap_id} ->
        ap_id == URI.to_string(actor_iri)

      _ ->
        Logger.debug("No current user")
        false
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, opts) do
    if conn.assigns[:current_user] do
      conn
    else
      require_authenticated_oauth_token(conn, opts)
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  ```
  import FediServerWeb.UserAuth, only: [require_authenticated_oauth_token: 2]

  pipeline :protected_api do
    plug(:accepts, ["json"])

    plug(:require_authenticated)
  end
  ```
  """
  def require_authenticated_oauth_token(conn, _opts) do
    with [authorization_header] <- get_req_header(conn, "authorization"),
         [_authorization_header, bearer] <- Regex.run(~r/Bearer (.+)/, authorization_header),
         {:ok, token} <- Authorization.AccessToken.authorize(value: bearer) do
      conn
      |> assign(:current_token, token)
      |> assign(:current_user, Accounts.get_user!(token.sub))
    else
      _ ->
        Logger.error("Authentication required")

        case get_format(conn) do
          "html" ->
            conn
            |> put_flash(:error, "You must log in to access this page.")
            |> maybe_store_return_to()
            |> redirect(to: Routes.user_session_path(conn, :new))
            |> halt()

          _ ->
            APUtils.send_json_resp(conn, :unauthorized)
        end
    end
  end

  @doc """
  Used to limit access to controller actions based on the Oauth scopes of the client.

  ```
  import FediServerWeb.UserAuth, only: [authorize: 2]

  plug(:authorize, ["read"]) when action in [:index, :show]
  plug(:authorize, ["write"]) when action in [:create, :update, :delete]
  ```
  """
  def authorize(conn, [_h | _t] = required_scopes) do
    current_scopes = Scope.split(conn.assigns[:current_token].scope)
    missing_scopes = required_scopes -- current_scopes

    if Enum.empty?(missing_scopes) do
      conn
    else
      Logger.error("Unauthorized, missing scopes #{inspect(missing_scopes)}")

      case get_format(conn) do
        "html" ->
          conn
          |> put_flash(:error, "You do not have proper permissions to access this page.")
          |> redirect(to: Routes.user_session_path(conn, :new))
          |> halt()

        _ ->
          APUtils.send_json_resp(conn, :forbidden)
      end
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(conn), do: Routes.timelines_path(conn, :home)
end
