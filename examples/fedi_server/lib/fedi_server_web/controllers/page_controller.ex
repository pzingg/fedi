defmodule FediServerWeb.PageController do
  use FediServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
