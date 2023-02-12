defmodule Fedi.ContentTest do
  use ExUnit.Case

  @input """
  @pzingg@mastodon.cloud
  # First post
  I read on wikipedia.org that #hashtags are
  important to finding things in the #fediverse.

  At least that's what @judell@mastodon.social says.
  """

  setup do
    FediServerWeb.MockRequestHelper.setup_mocks(__MODULE__)
  end

  test "parses links from markdown" do
    expected_markdown =
      """
      [@pzingg@mastodon.cloud](https://mastodon.cloud/users/pzingg)
      # First post
      I read on [wikipedia.org](wikipedia.org) that [#hashtags](https://example.com/hashtags/hashtags) are
      important to finding things in the [#fediverse](https://example.com/hashtags/fediverse).

      At least that's what [@judell@mastodon.social](https://mastodon.social/users/judell) says.
      """
      |> String.trim()

    assert {:ok, markdown, links} =
             Fedi.Content.parse_markdown(@input, webfinger_module: FediServerWeb.WebFinger)

    assert links[:urls] == [%{href: "wikipedia.org", name: "wikipedia.org"}]

    assert markdown == expected_markdown

    assert MapSet.new(links[:hashtags]) ==
             MapSet.new([
               %{href: "https://example.com/hashtags/hashtags", name: "#hashtags"},
               %{href: "https://example.com/hashtags/fediverse", name: "#fediverse"}
             ])

    assert MapSet.new(links[:mentions]) ==
             MapSet.new([
               %{href: "https://mastodon.cloud/users/pzingg", name: "@pzingg@mastodon.cloud"},
               %{href: "https://mastodon.social/users/judell", name: "@judell@mastodon.social"}
             ])
  end

  test "formats markdown as html with links" do
    expected_html =
      [
        "<p><a href=\"https://mastodon.cloud/users/pzingg\">@pzingg@mastodon.cloud</a></p><h1>First post</h1>",
        "<p>I read on <a href=\"wikipedia.org\">wikipedia.org</a> that",
        " <a href=\"https://example.com/hashtags/hashtags\">#hashtags</a> are",
        " important to finding things in the <a href=\"https://example.com/hashtags/fediverse\">#fediverse</a>.</p>",
        "<p>At least that&#39;s what <a href=\"https://mastodon.social/users/judell\">@judell@mastodon.social</a> says.</p>"
      ]
      |> Enum.join("")

    assert {:ok, html, _links} =
             Fedi.Content.parse_markdown(@input, html: true, compact_output: true)

    assert html == expected_html
  end

  test "does not re-make pure links that are already in markdown" do
    input =
      """
      # Problems for Elon
      I read on wikipedia.org that [Twitter](https://twitter.com?txt=1&reg=2) is losing subscribers.
      """
      |> String.trim()

    expected_markdown =
      """
      # Problems for Elon
      I read on [wikipedia.org](wikipedia.org) that [Twitter](https://twitter.com?txt=1&reg=2) is losing subscribers.
      """
      |> String.trim()

    assert {:ok, markdown, links} =
             Fedi.Content.parse_markdown(input, webfinger_module: FediServerWeb.WebFinger)

    assert markdown == expected_markdown
    assert links[:markdown_urls] == [%{href: "https://twitter.com?txt=1&reg=2", name: "Twitter"}]
    assert links[:urls] == [%{href: "wikipedia.org", name: "wikipedia.org"}]
  end

  test "does not re-make auto links that are already in markdown" do
    input =
      """
      # Problems for Elon
      I read on wikipedia.org that <https://twitter.com?txt=1&reg=2> is losing subscribers.
      """
      |> String.trim()

    expected_markdown =
      """
      # Problems for Elon
      I read on [wikipedia.org](wikipedia.org) that <https://twitter.com?txt=1&reg=2> is losing subscribers.
      """
      |> String.trim()

    assert {:ok, markdown, links} =
             Fedi.Content.parse_markdown(input, webfinger_module: FediServerWeb.WebFinger)

    assert markdown == expected_markdown

    assert links[:markdown_urls] == [
             %{href: "https://twitter.com?txt=1&reg=2", name: "https://twitter.com?txt=1&reg=2"}
           ]

    assert links[:urls] == [%{href: "wikipedia.org", name: "wikipedia.org"}]
  end

  test "does not re-make old-style links that are already in markdown" do
    input =
      """
      # Problems for Elon
      I read on wikipedia.org that [Twitter][1] is losing subscribers.
      [1]: https://twitter.com?txt=1&reg=2 "Twitter (the birdsite)"
      """
      |> String.trim()

    expected_markdown =
      """
      # Problems for Elon
      I read on [wikipedia.org](wikipedia.org) that [Twitter][1] is losing subscribers.
      [1]: https://twitter.com?txt=1&reg=2 "Twitter (the birdsite)"
      """
      |> String.trim()

    expected_html =
      [
        "<h1>Problems for Elon</h1>",
        "<p>I read on <a href=\"wikipedia.org\">wikipedia.org</a> that ",
        "<a href=\"https://twitter.com?txt=1&reg=2\" title=\"Twitter (the birdsite)\">Twitter</a> ",
        "is losing subscribers.</p>"
      ]
      |> Enum.join("")

    assert {:ok, markdown, links} =
             Fedi.Content.parse_markdown(input, webfinger_module: FediServerWeb.WebFinger)

    assert markdown == expected_markdown

    assert links[:markdown_urls] == [
             %{href: "https://twitter.com?txt=1&reg=2", name: "Twitter"}
           ]

    assert links[:urls] == [%{href: "wikipedia.org", name: "wikipedia.org"}]

    assert {:ok, html, _} =
             Fedi.Content.parse_markdown(input,
               html: true,
               compact_output: true,
               webfinger_module: FediServerWeb.WebFinger
             )

    assert html == expected_html
  end

  test "builds a note" do
    note = %{
      "type" => "Note",
      "content" => @input,
      "attributedTo" => "https://mastodon.cloud/users/pzingg"
    }

    assert {:ok, note} = Fedi.Content.set_tags(note)
    note = Fedi.Client.set_visibility(note, :unlisted)

    assert note["to"] == "https://mastodon.cloud/users/pzingg"

    assert MapSet.new(note["cc"]) ==
             MapSet.new([
               "https://www.w3.org/ns/activitystreams#Public",
               "https://mastodon.cloud/users/pzingg/followers",
               "https://mastodon.social/users/judell"
             ])

    assert Map.get(note, "tag", []) |> MapSet.new() ==
             MapSet.new([
               %{
                 "href" => "https://mastodon.social/users/judell",
                 "name" => "@judell@mastodon.social",
                 "type" => "Mention"
               },
               %{
                 "href" => "https://mastodon.cloud/users/pzingg",
                 "name" => "@pzingg@mastodon.cloud",
                 "type" => "Mention"
               },
               %{
                 "href" => "https://example.com/hashtags/fediverse",
                 "name" => "#fediverse",
                 "type" => "Hashtag"
               },
               %{
                 "href" => "https://example.com/hashtags/hashtags",
                 "name" => "#hashtags",
                 "type" => "Hashtag"
               }
             ])
  end
end
