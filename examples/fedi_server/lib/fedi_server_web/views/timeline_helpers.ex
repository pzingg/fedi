defmodule FediServerWeb.TimelineHelpers do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Utils
  alias FediServer.Accounts.User
  alias FediServer.Activities

  def transform(
        %{activity: %{"type" => "Announce", "id" => boost_id}, actor: actor_data} = activity
      ) do
    booster_info =
      get_actor_info(%{data: actor_data})
      |> Map.put(:activity_id, boost_id)

    activity
    |> Map.put(:domain, :activities)
    |> transform(booster_info)
  end

  def transform(activity) do
    transform(activity, nil)
  end

  def transform(
        %{
          id: ulid,
          actor: actor_map_or_id,
          object: %{"id" => _} = object
        } = activity,
        booster_info
      )
      when is_map(object) do
    actor_id =
      if is_map(actor_map_or_id) do
        Map.get(actor_map_or_id, "id")
      else
        actor_map_or_id
      end

    attributed_to_id = Map.get(object, "attributedTo")

    actor_map_or_id =
      if is_nil(attributed_to_id) || attributed_to_id == actor_id do
        actor_map_or_id
      else
        attributed_to_id
      end

    actor =
      if is_map(actor_map_or_id) do
        actor_map_or_id
      else
        case Activities.get_object_data(actor_map_or_id) do
          {:ok, actor} ->
            actor

          _ ->
            Logger.error("timeline item has no actor: #{inspect(activity)}")
            nil
        end
      end

    domain = Map.get(activity, :domain, :objects)
    transform(actor, domain, ulid, object, booster_info)
  end

  def transform(%{object: object}, _booster_info) when is_map(object) do
    Logger.error("timeline item object has no id: #{inspect(object)}")
    nil
  end

  def transform(%{object: object}, _booster_info) do
    Logger.error("timeline item object is not a map: #{inspect(object)}")
    nil
  end

  def transform(activity, _booster_info) do
    missing_keys = [:id, :actor] |> Enum.reject(&Map.has_key?(activity, &1))
    Logger.error("timeline item mising required keys: #{inspect(missing_keys)}")
    nil
  end

  def transform(nil, _domain, _ulid, _object, _booster_info), do: nil

  def transform(actor, domain, ulid, %{"id" => object_id} = object, booster_info) do
    actor_info = get_actor_info(%{data: actor})

    reply_count =
      case Activities.reply_count(object_id) do
        0 -> ""
        _n -> "1+"
      end

    content = object["content"]

    content_html =
      case Fedi.Content.parse_markdown(content,
             html: true,
             webfinger_module: FediServerWeb.WebFinger
           ) do
        {:ok, html, _} -> html
        _ -> "<p>#{content}</p>"
      end

    content_text =
      case Fedi.Content.as_text(content) do
        {:ok, text} -> text
        _ -> ""
      end

    published = get_published(object)
    days_past = Timex.diff(DateTime.utc_now(), published, :day)

    published_relative =
      if days_past < 3 do
        Timex.from_now(published)
      else
        Timex.format!(published, "{Mshort} {D}, {YYYY}")
      end

    published_title = Timex.format!(published, "{Mshort} {D}, {YYYY}, {h24}:{m}")
    aria_label = "#{content_text}, #{published_title}, #{actor_info.nickname}"

    assigns = %{
      domain: domain,
      id: ulid,
      boost_id: nil,
      aria_label: aria_label,
      object_id: object_id,
      published_relative: published_relative,
      published_title: published_title,
      published_utc: Timex.format!(published, "{ISO:Basic:Z}"),
      attributed_to_name: actor_info.name,
      attributed_to_account: actor_info.account,
      attributed_to_url: actor_info.url,
      attributed_to_avatar_url: actor_info.avatar_url,
      content_html: content_html,
      reply_count: reply_count
    }

    if booster_info do
      Map.merge(assigns, %{
        boost_id: booster_info.activity_id,
        booster_name: booster_info.name,
        booster_url: booster_info.url
      })
    else
      assigns
    end
  end

  def get_published(object) do
    with dt_string when is_binary(dt_string) <- Map.get(object, "published"),
         {:ok, dt} <- Timex.parse(dt_string, "{RFC3339z}") do
      dt
    else
      _ ->
        Logger.error("no valid 'published' in #{inspect(object)}")
        DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  def get_actor_info(
        %{
          data:
            %{"id" => id, "preferredUsername" => nickname, "name" => name, "url" => url} =
              actor_data
        } = actor
      ) do
    %URI{host: domain} = Utils.to_uri(id)

    avatar_url =
      actor[:avatar_url] ||
        get_in(actor_data, ["icon", "url"]) ||
        User.make_gravatar_url("#{nickname}@#{domain}")

    %{
      id: id,
      url: url,
      nickname: nickname,
      account: "@#{nickname}@#{domain}",
      name: name,
      avatar_url: avatar_url
    }
  end

  def get_actor_info(_actor_data), do: nil

  def next_url(route_url, statuses) do
    case List.last(statuses) do
      %{id: last_id} ->
        %URI{} = route = Utils.to_uri(route_url)
        %URI{route | query: "max_id=#{last_id}&page=true"} |> URI.to_string()

      _ ->
        nil
    end
  end
end
