defmodule FediServerWeb.OauthView do
  use FediServerWeb, :view

  alias Boruta.Oauth.IntrospectResponse
  alias Boruta.Oauth.TokenResponse

  def render("token.json", %{
        response: %TokenResponse{
          token_type: token_type,
          access_token: access_token,
          expires_in: expires_in,
          refresh_token: refresh_token,
          id_token: id_token
        }
      }) do
    Enum.filter(
      %{
        token_type: token_type,
        access_token: access_token,
        expires_in: expires_in,
        refresh_token: refresh_token,
        id_token: id_token
      },
      fn
        {_key, nil} -> false
        _ -> true
      end
    )
    |> Enum.into(%{})
  end

  def render("introspect.json", %{
        response: %IntrospectResponse{
          active: active,
          client_id: client_id,
          username: username,
          scope: scope,
          sub: sub,
          iss: iss,
          exp: exp,
          iat: iat
        }
      }) do
    case active do
      true ->
        %{
          active: true,
          client_id: client_id,
          username: username,
          scope: scope,
          sub: sub,
          iss: iss,
          exp: exp,
          iat: iat
        }

      false ->
        %{active: false}
    end
  end

  def render("error.json", %{error: error, error_description: error_description}) do
    %{
      error: error,
      error_description: error_description
    }
  end
end
