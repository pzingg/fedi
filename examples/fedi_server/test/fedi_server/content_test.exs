defmodule FediServer.ContentTest do
  use ExUnit.Case

  @input """
  @pzingg@mastodon.cloud
  # First post
  I read on wikipedia.org that #hashtags are
  important to finding things in the #fediverse.

  At least that's what @judell@mastodon.social says.
  """

  test "parses links from markdown" do
    expected_markdown =
      """
      [@pzingg@mastodon.cloud](https://chatty.example/users/pzingg)
      # First post
      I read on [wikipedia.org](wikipedia.org) that [#hashtags](https://chatty.example/tags/hashtags) are
      important to finding things in the [#fediverse](https://chatty.example/tags/fediverse).

      At least that's what [@judell@mastodon.social](https://chatty.example/users/judell) says.
      """
      |> String.trim()

    assert {:ok, markdown, links} = FediServer.Content.parse_markdown(@input)
    assert links[:urls] == [%{href: "wikipedia.org", name: "wikipedia.org"}]

    assert markdown == expected_markdown

    assert MapSet.new(links[:hashtags]) ==
             MapSet.new([
               %{href: "https://chatty.example/tags/hashtags", name: "#hashtags"},
               %{href: "https://chatty.example/tags/fediverse", name: "#fediverse"}
             ])

    assert MapSet.new(links[:mentions]) ==
             MapSet.new([
               %{href: "https://chatty.example/users/pzingg", name: "@pzingg@mastodon.cloud"},
               %{href: "https://chatty.example/users/judell", name: "@judell@mastodon.social"}
             ])
  end

  test "formats markdown as html with links" do
    expected_html =
      [
        "<p><a href=\"https://chatty.example/users/pzingg\">@pzingg@mastodon.cloud</a></p><h1>First post</h1>",
        "<p>I read on <a href=\"wikipedia.org\">wikipedia.org</a> that",
        " <a href=\"https://chatty.example/tags/hashtags\">#hashtags</a> are",
        " important to finding things in the <a href=\"https://chatty.example/tags/fediverse\">#fediverse</a>.</p>",
        "<p>At least that&#39;s what <a href=\"https://chatty.example/users/judell\">@judell@mastodon.social</a> says.</p>"
      ]
      |> Enum.join("")

    assert {:ok, html, _links} =
             FediServer.Content.parse_markdown(@input, html: true, compact_output: true)

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

    assert {:ok, markdown, links} = FediServer.Content.parse_markdown(input)
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

    assert {:ok, markdown, links} = FediServer.Content.parse_markdown(input)
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

    assert {:ok, markdown, links} = FediServer.Content.parse_markdown(input)
    assert markdown == expected_markdown

    assert links[:markdown_urls] == [
             %{href: "https://twitter.com?txt=1&reg=2", name: "Twitter"}
           ]

    assert links[:urls] == [%{href: "wikipedia.org", name: "wikipedia.org"}]

    assert {:ok, html, _} =
             FediServer.Content.parse_markdown(input, html: true, compact_output: true)

    assert html == expected_html
  end
end
