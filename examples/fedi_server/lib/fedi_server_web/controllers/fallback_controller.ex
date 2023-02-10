defmodule FediServerWeb.FallbackController do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(FediServerWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :internal_server_error}) do
    conn
    |> put_status(:internal_server_error)
    |> put_view(FediServerWeb.ErrorView)
    |> render(:"500")
  end
end
