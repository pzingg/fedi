defmodule FediServerWeb.Oauth.AuthorizeController do
  @behaviour Boruta.Oauth.AuthorizeApplication

  use FediServerWeb, :controller

  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ResourceOwner
  alias FediServer.Oauth
  alias FediServerWeb.OauthView

  def oauth_module, do: Application.get_env(:fedi_server, :oauth_module, Boruta.Oauth)

  def authorize(%Plug.Conn{} = conn, _params) do
    current_user = conn.assigns[:current_user]
    conn = store_user_return_to(conn)

    authorize_response(
      conn,
      current_user
    )
  end

  defp authorize_response(conn, %_{} = current_user) do
    # Modified Boruta logic. The client must be owned by the current_user.
    if valid_client_id_for_current_user?(conn, current_user) do
      conn
      |> oauth_module().authorize(
        %ResourceOwner{sub: to_string(current_user.id), username: current_user.email},
        __MODULE__
      )
    else
      error = %Error{
        status: :unauthorized,
        error: :invalid_client,
        error_description: "Invalid client_id."
      }

      authorize_error(conn, error)
    end
  end

  defp authorize_response(conn, _nil) do
    redirect_to_login(conn)
  end

  defp valid_client_id_for_current_user?(_conn, nil), do: true

  defp valid_client_id_for_current_user?(%{"client_id" => client_id}, current_user) do
    case Oauth.get_client(client_id) do
      # This will be handled elsewhere
      nil -> true
      client -> client.user_id == current_user.id
    end
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_success(
        conn,
        %AuthorizeResponse{} = response
      ) do
    conn
    |> redirect(external: AuthorizeResponse.redirect_to_url(response))
    |> halt()
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_error(
        %Plug.Conn{} = conn,
        %Error{status: :unauthorized}
      ) do
    redirect_to_login(conn)
  end

  def authorize_error(
        conn,
        %Error{format: format} = error
      )
      when not is_nil(format) do
    conn
    |> redirect(external: Error.redirect_to_url(error))
  end

  def authorize_error(
        conn,
        %Error{status: status, error: error, error_description: error_description}
      ) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.html", error: error, error_description: error_description)
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_success(_conn, _response), do: :ok

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_error(_conn, _response), do: :ok

  defp store_user_return_to(conn) do
    conn
    |> put_session(
      :user_return_to,
      current_path(conn)
    )
  end

  # Here occurs the login process. After login, user may be redirected to
  # `get_session(conn, :user_return_to)`
  defp redirect_to_login(conn) do
    conn
    |> redirect(to: Routes.user_session_path(conn, :new))
    |> halt()
  end
end
