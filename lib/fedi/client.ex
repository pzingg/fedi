defmodule Fedi.Client do
  @moduledoc """
  Convenience functions for setting up ActivityPub payloads.
  """

  require Logger

  alias Fedi.Streams.Utils

  @doc """
  Create a new post

  ## Examples:

    iex> Fedi.Client.post("https://example.com/users/me", "**My Markdown post** mentioning @mentioned@other.example")
    %{
      "type" => "Create",
      "to" => "https://www.w3.org/ns/activitystreams#Public",
      "cc" => [
        "https://example.com/users/me/followers",
        "https://other.example/users/mentioned"
      ],
      "actor" => "https://example.com/users/me",
      "object" => %{
        "type" => "Note",
        "content" => "**My Markdown post** mentioning @mentioned@other.example",
        "mediaType" => "text/markdown",
        "attributedTo" => "https://example.com/users/me",
        "tag" => [
          %{
            "type" => "Mention",
            "href" => "https://other.example/users/mentioned",
            "name" => "@mentioned@other.example"
          }
        ]
      }
    }
  """
  def post(actor_id, markdown_content, m \\ %{}, opts \\ []) do
    visibility = Keyword.get(opts, :visibility, :public)

    m
    |> Map.merge(%{
      "type" => "Create",
      "actor" => actor_id,
      "object" => %{
        "type" => "Note",
        "content" => markdown_content,
        "attributedTo" => actor_id
      }
    })
    |> set_object_tags(opts)
    |> set_visibility(visibility)
  end

  @doc """
  Create a direct message.
  Must not have any "https://www.w3.org/ns/activitystreams#Public" or follower audience.

  ## Examples:

    iex> Fedi.Client.direct("https://example.com/users/me", "**My Markdown message**", %{"to" => "https://example.com/users/someone"})
    %{
      "type" => "Create",
      "to" => "https://example.com/users/someone",
      "actor" => "https://example.com/users/me",
      "object" => %{
        "type" => "Note",
        "content" => "**My Markdown message**",
        "mediaType" => "text/markdown",
        "attributedTo" => "https://example.com/users/me"
      }
    }
  """
  def direct(actor_id, markdown_content, m \\ %{}, opts \\ []) do
    opts = Keyword.put(opts, :visibility, :direct)
    post(actor_id, markdown_content, m, opts)
  end

  @doc """
  Reply to a post.

  ## Examples:

    iex> Fedi.Client.reply("https://example.com/users/me", "https://example.com/users/original/objects/OBJECTID", "@original@example.com **My Markdown reply**")
    %{
      "type" => "Create",
      "to" =>  "https://www.w3.org/ns/activitystreams#Public",
      "cc" => [
        "https://example.com/users/me/followers",
        "https://example.com/users/original"
      ],
      "actor" => "https://example.com/users/me",
      "object" => %{
        "type" => "Note",
        "content" => "@original@example.com **My Markdown reply**",
        "mediaType" => "text/markdown",
        "attributedTo" => "https://example.com/users/me",
        "inReplyTo" => "https://example.com/users/original/objects/OBJECTID",
        "tag" => [
          %{
            "type" => "Mention",
            "href" => "https://example.com/users/original",
            "name" => "@original@example.com"
          }
        ]
      }
    }
  """
  def reply(actor_id, in_reply_to_id, markdown_content, m \\ %{}, opts \\ []) do
    visibility = Keyword.get(opts, :visibility, :public)

    m
    |> Map.merge(%{
      "type" => "Create",
      "actor" => actor_id,
      "object" => %{
        "type" => "Note",
        "content" => markdown_content,
        "attributedTo" => actor_id,
        "inReplyTo" => in_reply_to_id
      }
    })
    |> set_object_tags(opts)
    |> set_visibility(visibility)
  end

  @doc """
  Boost an exisiting post.
  TODO: Does not extract tags from referenced object.

  ## Examples:

    iex> Fedi.Client.boost("https://example.com/users/me", "https://example.com/users/original/objects/OBJECTID")
    %{
      "type" => "Announce",
      "to" => "https://www.w3.org/ns/activitystreams#Public",
      "cc" => "https://example.com/users/me/followers",
      "actor" => "https://example.com/users/me",
      "object" => "https://example.com/users/original/objects/OBJECTID"
    }
  """
  def boost(actor_id, object_id, m \\ %{}, opts \\ []) do
    visibility = Keyword.get(opts, :visibility, :public)

    m
    |> Map.merge(%{
      "type" => "Announce",
      "actor" => actor_id,
      "object" => object_id
    })
    |> set_visibility(visibility)
  end

  @doc """
  Add to favourites.

  ## Examples:

    iex> Fedi.Client.favourite("https://example.com/users/me", "https://example.com/users/original/objects/OBJECTID")
    %{
      "type" => "Add",
      "to" => "https://example.com/users/me",
      "actor" => "https://example.com/users/me",
      "object" => "https://example.com/users/original/objects/OBJECTID",
      "target" => "https://example.com/users/me/favourites"
    }
  """
  def favourite(actor_id, object_id, m \\ %{}) do
    m
    |> Map.merge(%{
      "type" => "Add",
      "actor" => actor_id,
      "object" => object_id,
      "target" => "#{actor_id}/favourites"
    })
    |> set_visibility(:direct)
  end

  def set_visibility(m, visibility) do
    actor_id = get_actor(m)
    to = Map.get(m, "to", []) |> List.wrap() |> Enum.reject(&Utils.public?(&1))
    cc = Map.get(m, "cc", []) |> List.wrap() |> Enum.reject(&Utils.public?(&1))

    {to, cc} =
      case visibility do
        :public ->
          {[Utils.public_activity_streams() | to], ["#{actor_id}/followers" | cc]}

        :unlisted ->
          {["#{actor_id}/followers" | to], [Utils.public_activity_streams() | cc]}

        :followers_only ->
          {["#{actor_id}/followers" | to], cc}

        :direct ->
          {to, cc}
      end

    to =
      if Enum.empty?(to) do
        [actor_id]
      else
        MapSet.new(to) |> MapSet.to_list()
      end

    cc = Enum.reject(cc, &Enum.member?(to, &1)) |> MapSet.new() |> MapSet.to_list()
    m = Map.put(m, "to", unwrap(to))

    case unwrap(cc) do
      nil -> Map.delete(m, "cc")
      c -> Map.put(m, "cc", c)
    end
  end

  def set_object_tags(m, opts \\ []) do
    with %{"content" => content} = object when is_binary(content) <-
           Map.get(m, "object"),
         {:ok, object} <-
           Fedi.Content.set_tags(object, opts) do
      {cc, object} = Map.pop(object, "cc")

      m = Map.put(m, "object", object)

      case cc do
        nil ->
          m

        _ ->
          Map.update(m, "cc", cc, fn c -> List.wrap(c) ++ List.wrap(cc) end)
      end
    else
      _ ->
        m
    end
  end

  def get_actor(m) do
    (Map.get(m, "actor") || Map.fetch!(m, "attributedTo")) |> unwrap()
  end

  def unwrap([]), do: nil
  def unwrap([item]), do: item
  def unwrap(l), do: l

  def remove_public(m, prop_name) do
    if Map.has_key?(m, prop_name) do
      prop =
        m[prop_name]
        |> List.wrap()
        |> Enum.map(fn addr ->
          if Utils.public?(addr) do
            nil
          else
            addr
          end
        end)
        |> Enum.reject(&is_nil/1)

      case prop do
        [] -> Map.delete(m, prop)
        [addr] -> Map.put(m, prop_name, addr)
        _ -> Map.put(m, prop_name, prop)
      end
    else
      m
    end
  end
end
