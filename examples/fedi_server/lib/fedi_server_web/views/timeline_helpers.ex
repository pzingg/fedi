defmodule FediServerWeb.TimelineHelpers do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Utils
  alias FediServer.Activities

  def transform(%{activity: %{"type" => "Announce", "id" => boost_id}, actor: actor} = activity) do
    booster_info =
      get_actor_info(actor)
      |> Map.put(:activity_id, boost_id)

    transform(activity, booster_info)
  end

  def transform(activity) do
    transform(activity, nil)
  end

  def transform(
        %{
          object: %{"id" => object_id} = object,
          actor: %{"id" => actor_id} = actor
        },
        booster_info
      ) do
    attributed_to_id = Map.get(object, "attributedTo")

    actor =
      if !is_nil(attributed_to_id) and attributed_to_id != actor_id do
        case Activities.get_object_data(attributed_to_id) do
          {:ok, attributed_to} -> attributed_to
          _ -> actor
        end
      else
        actor
      end

    actor_info = get_actor_info(actor)

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

  def transform(timeline_item, _booster_info) do
    cond do
      is_nil(timeline_item.object) ->
        Logger.debug("timeline_item not complete, object: #{inspect(timeline_item)}")

      is_nil(timeline_item.actor) ->
        Logger.debug("timeline_item not complete, actor: #{inspect(timeline_item)}")

      is_nil(timeline_item.activity) ->
        Logger.debug("timeline_item not complete, activity: #{inspect(timeline_item)}")

      true ->
        :ok
    end

    nil
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

  def get_actor_info(%{"id" => id, "preferredUsername" => nickname, "name" => name, "url" => url}) do
    %URI{host: domain} = Utils.to_uri(id)

    %{
      id: id,
      url: url,
      nickname: nickname,
      account: "@#{nickname}@#{domain}",
      name: name,
      avatar_url:
        "https://media.mastodon.cloud/accounts/avatars/000/018/356/original/8fb7c58e48468071.jpg"
    }
  end

  def get_actor_info(_actor_data), do: nil
end
