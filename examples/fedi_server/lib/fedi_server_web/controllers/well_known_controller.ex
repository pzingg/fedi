defmodule FediServerWeb.WellKnownController do
  @moduledoc """
  From Pleroma: A lightweight social networking server
  Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
  SPDX-License-Identifier: AGPL-3.0-only
  """

  use FediServerWeb, :controller

  require Logger

  alias Fedi.Streams.Utils
  alias FediServerWeb.WebFinger

  def nodeinfo(%Plug.Conn{} = conn, _params) do
    endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()

    nodeinfo_version_url = Utils.base_uri(endpoint_uri, "/nodeinfo/2.0") |> URI.to_string()

    links_data = %{
      links: [
        %{
          rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
          href: nodeinfo_version_url
        }
      ]
    }

    body = Jason.encode!(links_data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  def nodeinfo_version(%Plug.Conn{} = conn, %{"version" => vsn = "2.0"} = _params) do
    nodeinfo_data = %{
      version: vsn,
      software: %{name: "fedi-server", version: "0.1.0"},
      protocols: ["activitypub"],
      usage: %{
        users: %{
          total: 237_123,
          activeMonth: 10_438,
          activeHalfyear: 229_348
        },
        localPosts: 4_772_533
      },
      openRegistrations: false
    }

    body = Jason.encode!(nodeinfo_data)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  def nodeinfo_version(%Plug.Conn{} = conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, "Only version 2.0 is supported")
  end

  def hostmeta(%Plug.Conn{} = conn, _params) do
    xml = WebFinger.host_meta()

    conn
    |> put_resp_content_type("application/xrd+xml")
    |> send_resp(200, xml)
  end

  def webfinger(%Plug.Conn{} = conn, %{"resource" => resource}) do
    format = get_format(conn)

    cond do
      format in ["xml", "xrd+xml"] ->
        with {:ok, response} <- WebFinger.webfinger(resource, :xml) do
          conn
          |> put_resp_content_type("application/xrd+xml")
          |> send_resp(200, response)
        else
          _ -> send_resp(conn, 404, "Resource not found")
        end

      format in ["json", "jrd+json"] ->
        with {:ok, response} <- WebFinger.webfinger(resource, :json) do
          json(conn, response)
        else
          _ ->
            conn
            |> put_status(404)
            |> json("Resource not found")
        end

      true ->
        Logger.error("webfinger bad format: #{inspect(format)}")
        send_resp(conn, 406, "Not acceptable")
    end
  end

  def webfinger(%Plug.Conn{} = conn, params) do
    Logger.error("webfinger bad params: #{inspect(params)}")
    send_resp(conn, 400, "Bad Request")
  end
end
