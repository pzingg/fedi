defmodule FediServerWeb.WebFinger do
  @moduledoc """
  From Pleroma: A lightweight social networking server
  Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
  SPDX-License-Identifier: AGPL-3.0-only
  """

  require Logger

  alias FediServer.Activities
  alias FediServer.Activities.User
  alias FediServer.HTTPClient
  alias FediServerWeb.XMLBuilder

  @accept_header_value_xml "application/xrd+xml"
  @accept_header_value_json "application/jrd+json"

  def host_meta do
    base_url = FediServerWeb.Endpoint.url()

    {
      :XRD,
      %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      {
        :Link,
        %{
          rel: "lrdd",
          type: @accept_header_value_xml,
          template: "#{base_url}/.well-known/webfinger?resource={uri}"
        }
      }
    }
    |> XMLBuilder.to_doc()
  end

  def webfinger(resource, fmt) when is_binary(resource) and fmt in [:xml, :json] do
    host = FediServerWeb.Endpoint.host()

    regex =
      if webfinger_domain = Application.get_env(:fedi_server, :web_finger_domain) do
        ~r/(acct:)?(?<username>[a-z0-9A-Z_\.-]+)@(#{host}|#{webfinger_domain})/
      else
        ~r/(acct:)?(?<username>[a-z0-9A-Z_\.-]+)@#{host}/
      end

    with %{"username" => nickname} <- Regex.named_captures(regex, resource),
         %User{} = user <- Activities.repo_get(:actors, nickname) do
      {:ok, represent_user(user, fmt)}
    else
      _ ->
        resource = URI.parse(resource)

        with %User{} = user <- Activities.repo_get_by_ap_id(:actors, resource) do
          {:ok, represent_user(user, fmt)}
        else
          _ ->
            {:error, "User not found"}
        end
    end
  end

  defp gather_links(%User{} = user) do
    [
      %{
        "rel" => "self",
        "type" => "application/activity+json",
        "href" => user.ap_id
      }
      # %{
      #  "rel" => "http://webfinger.net/rel/profile-page",
      #  "type" => "text/html",
      #  "href" => user.ap_id
      # }
    ]
  end

  defp gather_aliases(%User{} = user) do
    # | user.also_known_as]
    [user.ap_id]
  end

  def represent_user(user, :json) do
    %{
      "subject" => "acct:#{user.nickname}@#{domain()}",
      "aliases" => gather_aliases(user),
      "links" => gather_links(user)
    }
  end

  def represent_user(user, :xml) do
    aliases =
      user
      |> gather_aliases()
      |> Enum.map(&{:Alias, &1})

    links =
      gather_links(user)
      |> Enum.map(fn link -> {:Link, link} end)

    {
      :XRD,
      %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      [
        {:Subject, "acct:#{user.nickname}@#{domain()}"}
      ] ++ aliases ++ links
    }
    |> XMLBuilder.to_doc()
  end

  defp domain do
    Application.get_env(:fedi_server, :web_finger_domain) || FediServerWeb.Endpoint.host()
  end

  defp webfinger_from_xml(body) do
    with {:ok, doc} <- parse_document(body) do
      subject = string_from_xpath("//Subject", doc)

      subscribe_address =
        ~s{//Link[@rel="http://ostatus.org/schema/1.0/subscribe"]/@template}
        |> string_from_xpath(doc)

      ap_id =
        ~s{//Link[@rel="self" and @type="application/activity+json"]/@href}
        |> string_from_xpath(doc)

      data = %{
        "subject" => subject,
        "subscribe_address" => subscribe_address,
        "ap_id" => ap_id
      }

      {:ok, data}
    end
  end

  defp webfinger_from_json(body) do
    with {:ok, doc} <- Jason.decode(body) do
      data =
        Enum.reduce(doc["links"], %{"subject" => doc["subject"]}, fn link, data ->
          case {link["type"], link["rel"]} do
            {"application/activity+json", "self"} ->
              Map.put(data, "ap_id", link["href"])

            {"application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"", "self"} ->
              Map.put(data, "ap_id", link["href"])

            {nil, "http://ostatus.org/schema/1.0/subscribe"} ->
              Map.put(data, "subscribe_address", link["template"])

            _ ->
              Logger.debug("Unhandled type: #{inspect(link["type"])}")
              data
          end
        end)

      {:ok, data}
    end
  end

  def get_template_from_xml(body) do
    xpath = "//Link[@rel='lrdd']/@template"

    with {:ok, doc} <- parse_document(body),
         template when template != nil <- string_from_xpath(xpath, doc) do
      {:ok, template}
    end
  end

  def find_lrdd_template(domain) do
    # WebFinger is restricted to HTTPS - https://tools.ietf.org/html/rfc7033#section-9.1
    meta_url = "https://#{domain}/.well-known/host-meta"

    with {:ok, body, _headers} <- get(meta_url, ["application/json"]) do
      get_template_from_xml(body)
    else
      error ->
        Logger.warn("Can't find LRDD template in #{inspect(meta_url)}: #{inspect(error)}")
        {:error, :lrdd_not_found}
    end
  end

  defp get_address_from_domain(domain, encoded_account) when is_binary(domain) do
    case find_lrdd_template(domain) do
      {:ok, template} ->
        String.replace(template, "{uri}", encoded_account)

      _ ->
        "https://#{domain}/.well-known/webfinger?resource=#{encoded_account}"
    end
  end

  defp get_address_from_domain(_, _), do: {:error, :webfinger_no_domain}

  def finger(%URI{host: domain} = account) do
    if HTTPClient.is_http_uri?(account) do
      finger(URI.to_string(account), domain)
    else
      {:error, "WebFinger: account is not an HTTP URL"}
    end
  end

  def finger(account) when is_binary(account) do
    account = String.trim_leading(account, "@")

    with [_name, domain] <- String.split(account, "@") do
      finger(account, domain)
    else
      _ ->
        {:error, "WebFinger: account is not an '@' address"}
    end
  end

  def finger(account, domain) do
    encoded_account = URI.encode("acct:#{account}")
    address = get_address_from_domain(domain, encoded_account)

    with {:ok, body, headers} <-
           get(address, [@accept_header_value_xml, @accept_header_value_json]) do
      case List.keyfind(headers, "content-type", 0) do
        {_, content_type} ->
          case Plug.Conn.Utils.media_type(content_type) do
            {:ok, "application", subtype, _} when subtype in ~w(xrd+xml xml) ->
              webfinger_from_xml(body)

            {:ok, "application", subtype, _} when subtype in ~w(jrd+json json) ->
              webfinger_from_json(body)

            _ ->
              {:error, {:content_type, content_type}}
          end

        _ ->
          {:error, {:content_type, nil}}
      end
    else
      {:error, reason} ->
        Logger.error("Couldn't finger #{account}: #{reason}")
        {:error, reason}
    end
  end

  def string_from_xpath(_, :error), do: nil

  def string_from_xpath(xpath, doc) do
    try do
      {:xmlObj, :string, res} = :xmerl_xpath.string('string(#{xpath})', doc)

      res =
        res
        |> to_string
        |> String.trim()

      if res == "", do: nil, else: res
    catch
      _e ->
        Logger.debug("Couldn't find xpath #{xpath} in XML doc")
        nil
    end
  end

  def parse_document(text) do
    try do
      {doc, _rest} =
        text
        |> :binary.bin_to_list()
        |> :xmerl_scan.string(quiet: true)

      {:ok, doc}
    rescue
      _e ->
        Logger.debug("Couldn't parse XML: #{inspect(text)}")
        :error
    catch
      :exit, _error ->
        Logger.debug("Couldn't parse XML: #{inspect(text)}")
        :error
    end
  end

  def get(url, accept_headers) when is_binary(url) do
    app_agent = FediServer.Application.app_agent()
    transport = HTTPClient.anonymous(app_agent)
    date_str = Fedi.ActivityPub.Utils.date_header_value()

    headers =
      [
        {"accept-charset", "utf-8"},
        {"user-agent", "#{transport.app_agent} #{transport.user_agent}"},
        {"date", date_str}
      ] ++ Enum.map(accept_headers, fn value -> {"accept", value} end)

    opts = [
      method: :get,
      url: url,
      headers: headers
    ]

    case Tesla.request(transport.client, opts) do
      {:error, reason} ->
        {:error, reason}

      {:ok, %Tesla.Env{body: body, headers: headers} = env} ->
        if HTTPClient.success?(env.status) do
          {:ok, body, headers}
        else
          {:error, "Status #{env.status}"}
        end
    end
  end
end
