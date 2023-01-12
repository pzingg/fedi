defmodule FediServerWeb.WebFinger.WebFingerController do
  @moduledoc """
  From Pleroma: A lightweight social networking server
  Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
  SPDX-License-Identifier: AGPL-3.0-only
  """

  use FediServerWeb, :controller

  alias FediServerWeb.WebFinger

  def host_meta(conn, _params) do
    xml = WebFinger.host_meta()

    conn
    |> put_resp_content_type("application/xrd+xml")
    |> send_resp(200, xml)
  end

  def webfinger(%{assigns: %{format: format}} = conn, %{"resource" => resource})
      when format in ["xml", "xrd+xml"] do
    with {:ok, response} <- WebFinger.webfinger(resource, :xml) do
      conn
      |> put_resp_content_type("application/xrd+xml")
      |> send_resp(200, response)
    else
      _ -> send_resp(conn, 404, "Couldn't find user")
    end
  end

  def webfinger(%{assigns: %{format: format}} = conn, %{"resource" => resource})
      when format in ["json", "jrd+json"] do
    with {:ok, response} <- WebFinger.webfinger(resource, :json) do
      json(conn, response)
    else
      _ ->
        conn
        |> put_status(404)
        |> json("Couldn't find user")
    end
  end

  def webfinger(conn, _params), do: send_resp(conn, 400, "Bad Request")
end
