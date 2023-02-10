# Copyright © 2017-2018 E-MetroTel
# Copyright © 2019-2022 Pleroma Authors
# SPDX-License-Identifier: MIT
defmodule FediServer.Content do
  @moduledoc """
  Parse out links from Markdown content.

  From https://git.pleroma.social/pleroma/elixir-libraries/linkify,
  modified to not build HTML (we use Earmark for that).
  """

  require Logger

  alias Fedi.Streams.Utils

  @invalid_url ~r/(\.\.+)|(^(\d+\.){1,2}\d+$)/

  @match_url ~r{^(?:\W*)?(?<url>(?:https?:\/\/)?[\w.-]+(?:\.[\w\.-]+)+[\w\-\._~%:\/?#[\]@!\$&'\(\)\*\+,;=.]+$)}u

  @get_scheme_host ~r{^\W*(?<scheme>https?:\/\/)?(?:[^@\n]+\\w@)?(?<host>[^:#~\/\n?]+)}u

  @match_hashtag ~r/^(?<tag>\#[[:word:]_]*[[:alpha:]_·\x{200c}][[:word:]_·\p{M}\x{200c}]*)/u

  @match_skipped_tag ~r/^(?<tag>(a|code|pre)).*>*/

  @delimiters ~r/[,.;:>?!]*$/

  @en_apostrophes [
    "'",
    "'s",
    "'ll",
    "'d"
  ]

  @tlds Path.join(:code.priv_dir(:fedi_server), "tlds-alpha-by-domain.txt")
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.concat(["example", "onion"])
        |> MapSet.new()

  @default_opts %{
    validate_tld: true
  }

  @types [:url, :hashtag, :mention, :email]

  def build_note(note, actor_iri, visibility) when is_map(note) do
    content = note["content"]

    case parse_markdown(content) do
      {:error, reason} ->
        {:error, reason}

      {:ok, content, %{hashtags: hashtags, mentions: mentions} = _links} ->
        {mentions, mentioned} =
          Enum.map(mentions, fn %{name: name, href: href} ->
            {%{"type" => "Mention", "name" => name, "href" => href}, href}
          end)
          |> Enum.unzip()

        # TODO @context should have "as:Hashtag"
        hashtags =
          Enum.map(hashtags, fn %{name: name, href: href} ->
            %{"type" => "Hashtag", "name" => name, "href" => href}
          end)

        note =
          note
          |> Map.update("cc", mentioned, fn cc -> cc ++ mentioned end)
          |> Fedi.Client.set_visibility(actor_iri, visibility)

        {:ok,
         note
         |> Map.merge(%{
           "content" => content,
           "mediaType" => "text/markdown",
           "tag" => mentions ++ hashtags
         })}
    end
  end

  @doc """
  Parses a Markdown-formatted string, optionally converting to
  HTML.

  Options:

  - `:html` - if true, return HTML, otherwise return Markdown
  - `:compact_output` - if true, do not add newlines to the HTML output

  Returns a three-element :ok tuple. The second element is
  the markdown text, modified to insert ActivityPub-friendly
  links. The third element is a map with these items:

  - `:markdown_urls` - hyperlinks from the originally encoded markdown.
  - `:urls` - additional hyperlinks heuristically discovered.
  - `:hashtags` - hashtags
  - `:mentions` - Fediverse addresses, like `@user@instance.social`

  Each item is a list of maps, where the maps have `:href` and `:name`
  items.
  """
  # TODO Supply functions to map hashtag and mention names to URLs,
  # using Webfinger for mentions, and a URL prefix for hashags.
  def parse_markdown(markdown_content, opts \\ []) do
    input = String.trim(markdown_content)

    case Earmark.as_ast(input) do
      {:error, reason} ->
        {:error_reason}

      {:ok, ast, _} ->
        # Collect links that Markdown itself will parse
        {_ast, markdown_urls} =
          Earmark.Transform.map_ast_with(ast, [], fn
            {"a", attributes, [name | _], _} = node, acc ->
              href_attr =
                Enum.find(attributes, fn
                  {"href", u} -> true
                  _other -> false
                end)

              if is_nil(href_attr) do
                {node, acc}
              else
                url = elem(href_attr, 1)
                item = %{href: url, name: name}
                {node, [item | acc]}
              end

            node, acc ->
              {node, acc}
          end)

        markdown_hrefs = Enum.map(markdown_urls, fn %{href: href} -> href end)

        {to_html?, opts} = Keyword.pop(opts, :html)

        endpoint_uri = Fedi.Application.endpoint_url() |> Utils.to_uri()

        user_acc = %{
          endpoint_uri: endpoint_uri,
          markdown_hrefs: markdown_hrefs,
          markdown_urls: markdown_urls,
          urls: [],
          emails: [],
          mentions: [],
          hashtags: []
        }

        parser_opts = %{
          url_handler: &url_handler/4,
          mention_handler: &mention_handler/4,
          hashtag_handler: &hashtag_handler/4
        }

        {text, link_map} = parse({input, user_acc}, parser_opts)

        if to_html? do
          earmark_opts = Keyword.put(opts, :smartypants, false)

          case Earmark.as_html(text, earmark_opts) do
            {:ok, html, _} -> {:ok, html, link_map}
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, text, link_map}
        end
    end
  end

  @doc """
  Parse the given string, identifying items to link.

  Parses the string, replacing the matching urls with an html link.

  ## Examples

      iex> FediServer.Content.parse("Check out google.com")
      ~s{Check out <a href="http://google.com">google.com</a>}
  """
  def parse(input, opts \\ %{})
  def parse(input, opts) when is_binary(input), do: {input, %{}} |> parse(opts) |> elem(0)

  def parse(input, opts) when is_map(opts) do
    opts = Map.merge(@default_opts, opts)

    opts =
      if Map.get(opts, :url_handler) do
        Map.put(opts, :url, true)
      else
        opts
      end

    opts =
      if Map.get(opts, :email_handler) do
        Map.put(opts, :email, true)
      else
        opts
      end

    opts =
      if Map.get(opts, :hashtag_handler) do
        Map.put(opts, :hashtag, true)
      else
        opts
      end

    opts =
      if Map.get(opts, :mention_handler) do
        Map.put(opts, :mention, true)
      else
        opts
      end

    {buffer, user_acc} = do_parse(input, opts, {"", [], :parsing})

    if opts[:iodata] do
      {buffer, user_acc}
    else
      {IO.iodata_to_binary(buffer), user_acc}
    end
  end

  defp accumulate(acc, buffer),
    do: [buffer | acc]

  defp accumulate(acc, buffer, trailing),
    do: [trailing, buffer | acc]

  defp do_parse({"", user_acc}, _opts, {"", acc, _}),
    do: {Enum.reverse(acc), user_acc}

  defp do_parse(
         {"<" <> text, user_acc},
         %{hashtag: true} = opts,
         {"#" <> _ = buffer, acc, :parsing}
       ) do
    {buffer, user_acc} = link(buffer, opts, user_acc)

    buffer =
      case buffer do
        [_, _, _] -> Enum.join(buffer)
        _ -> buffer
      end

    case Regex.run(@match_skipped_tag, buffer, capture: [:tag]) do
      [tag] ->
        text = String.trim_leading(text, tag)
        do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<#{tag}"), :skip})

      nil ->
        do_parse({text, user_acc}, opts, {"<", accumulate(acc, buffer, ""), {:open, 1}})
    end
  end

  defp do_parse({"<br" <> text, user_acc}, opts, {buffer, acc, :parsing}) do
    {buffer, user_acc} = link(buffer, opts, user_acc)
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<br"), {:open, 1}})
  end

  defp do_parse({"<a" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<a"), :skip})

  defp do_parse({"<pre" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<pre"), :skip})

  defp do_parse({"<code" <> text, user_acc}, opts, {buffer, acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<code"), :skip})

  defp do_parse({"</a>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</a>"), :parsing})

  defp do_parse({"</pre>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</pre>"), :parsing})

  defp do_parse({"</code>" <> text, user_acc}, opts, {buffer, acc, :skip}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "</code>"), :parsing})

  defp do_parse({"<" <> text, user_acc}, opts, {"", acc, :parsing}),
    do: do_parse({text, user_acc}, opts, {"<", acc, {:open, 1}})

  defp do_parse({"<" <> text, user_acc}, opts, {buffer, acc, :parsing}) do
    {buffer, user_acc} = link(buffer, opts, user_acc)
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, "<"), {:open, 1}})
  end

  defp do_parse({">" <> text, user_acc}, opts, {buffer, acc, {:attrs, _level}}),
    do: do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer, ">"), :parsing})

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {"", acc, {:attrs, level}}) do
    do_parse({text, user_acc}, opts, {"", accumulate(acc, <<ch::8>>), {:attrs, level}})
  end

  defp do_parse({text, user_acc}, opts, {buffer, acc, {:open, level}}) do
    do_parse({text, user_acc}, opts, {"", accumulate(acc, buffer), {:attrs, level}})
  end

  defp do_parse(
         {<<char::bytes-size(1), text::binary>>, user_acc},
         opts,
         {buffer, acc, state}
       )
       when char in [" ", "\r", "\n"] do
    {buffer, user_acc} = link(buffer, opts, user_acc)

    do_parse(
      {text, user_acc},
      opts,
      {"", accumulate(acc, buffer, char), state}
    )
  end

  defp do_parse({<<ch::8>>, user_acc}, opts, {buffer, acc, state}) do
    {buffer, user_acc} = link(buffer <> <<ch::8>>, opts, user_acc)

    do_parse(
      {"", user_acc},
      opts,
      {"", accumulate(acc, buffer), state}
    )
  end

  defp do_parse({<<ch::8>> <> text, user_acc}, opts, {buffer, acc, state}),
    do: do_parse({text, user_acc}, opts, {buffer <> <<ch::8>>, acc, state})

  def check_and_link(:url, buffer, opts, user_acc) do
    if url?(buffer, opts) do
      case @match_url |> Regex.run(buffer, capture: [:url]) |> hd() do
        ^buffer ->
          link_url(buffer, buffer, opts, user_acc)

        url ->
          link = link_url(url, buffer, opts, user_acc)
          restore_stripped_symbols(buffer, url, link)
      end
    else
      :nomatch
    end
  end

  def check_and_link(:email, buffer, opts, user_acc) do
    if email?(buffer, opts), do: link_email(buffer, opts, user_acc), else: :nomatch
  end

  def check_and_link(:mention, buffer, opts, user_acc) do
    buffer
    |> match_mention
    |> link_mention(buffer, opts, user_acc)
  end

  def check_and_link(:hashtag, buffer, opts, user_acc) do
    buffer
    |> match_hashtag
    |> link_hashtag(buffer, opts, user_acc)
  end

  defp maybe_strip_parens(buffer) do
    trimmed = trim_leading_paren(buffer)

    with :next <- parens_check_trailing(buffer),
         :next <- parens_found_email(trimmed),
         :next <- parens_found_url(trimmed),
         %{path: path, query: query} = URI.parse(trimmed),
         :next <- parens_in_query(query),
         :next <- parens_found_path_separator(path),
         :next <- parens_path_has_open_paren(path),
         :next <- parens_check_balanced(trimmed) do
      buffer |> trim_leading_paren |> trim_trailing_paren
    else
      :both -> buffer |> trim_leading_paren |> trim_trailing_paren
      :leading_only -> buffer |> trim_leading_paren
      :noop -> buffer
      _ -> buffer
    end
  end

  defp parens_check_trailing(buffer), do: (String.ends_with?(buffer, ")") && :next) || :noop

  defp parens_found_email(trimmed),
    do: (trim_trailing_paren(trimmed) |> email?(nil) && :both) || :next

  defp parens_found_url(trimmed),
    do: (trim_trailing_paren(trimmed) |> url?(nil) && :next) || :noop

  defp parens_in_query(query), do: (is_nil(query) && :next) || :both
  defp parens_found_path_separator(path) when is_nil(path), do: :next
  defp parens_found_path_separator(path), do: (String.contains?(path, "/") && :next) || :both
  defp parens_path_has_open_paren(path) when is_nil(path), do: :next
  defp parens_path_has_open_paren(path), do: (String.contains?(path, "(") && :next) || :both

  defp parens_check_balanced(trimmed) do
    graphemes = String.graphemes(trimmed)
    opencnt = graphemes |> Enum.count(fn x -> x == "(" end)
    closecnt = graphemes |> Enum.count(fn x -> x == ")" end)

    if opencnt == closecnt do
      :leading_only
    else
      :next
    end
  end

  defp trim_leading_paren(buffer) do
    case buffer do
      "(" <> buffer -> buffer
      buffer -> buffer
    end
  end

  defp trim_trailing_paren(buffer),
    do:
      (String.ends_with?(buffer, ")") && String.slice(buffer, 0, String.length(buffer) - 1)) ||
        buffer

  defp strip_punctuation(buffer), do: String.replace(buffer, @delimiters, "")

  defp strip_en_apostrophes(buffer) do
    Enum.reduce(@en_apostrophes, buffer, fn abbrev, buf ->
      String.replace_suffix(buf, abbrev, "")
    end)
  end

  def url?(buffer, opts) do
    valid_url?(buffer) && Regex.match?(@match_url, buffer) && valid_tld?(buffer, opts)
  end

  def email?(buffer, opts) do
    # Note: In reality the local part can only be checked by the remote server
    case Regex.run(~r/^(?<user>.*)@(?<host>[^@]+)$/, buffer, capture: [:user, :host]) do
      [_user, hostname] -> valid_hostname?(hostname) && valid_tld?(hostname, opts)
      _ -> false
    end
  end

  defp valid_url?(url) do
    with {_, [scheme]} <- {:regex, Regex.run(@get_scheme_host, url, capture: [:scheme])},
         true <- scheme == "" do
      !Regex.match?(@invalid_url, url)
    else
      _ ->
        true
    end
  end

  @doc """
  Validates a URL's TLD. Returns a boolean.

  Will return `true` if `:validate_tld` option set to `false`.

  Will skip validation and return `true` if `:validate_tld` set to `:no_scheme` and the url has a scheme.
  """
  def valid_tld?(url, opts) do
    [scheme, host] = Regex.run(@get_scheme_host, url, capture: [:scheme, :host])

    cond do
      opts[:validate_tld] == false ->
        true

      scheme != "" && ip?(host) ->
        true

      # don't validate if scheme is present
      opts[:validate_tld] == :no_scheme and scheme != "" ->
        true

      true ->
        tld = host |> strip_punctuation() |> String.split(".") |> List.last()
        MapSet.member?(@tlds, tld)
    end
  end

  def safe_to_integer(string, base \\ 10) do
    String.to_integer(string, base)
  rescue
    _ ->
      nil
  end

  def ip?(buffer) do
    case :inet.parse_strict_address(to_charlist(buffer)) do
      {:error, _} -> false
      {:ok, _} -> true
    end
  end

  # IDN-compatible, ported from musl-libc's is_valid_hostname()
  def valid_hostname?(hostname) do
    hostname
    |> String.to_charlist()
    |> Enum.any?(fn s ->
      !(s >= 0x80 || s in 0x30..0x39 || s in 0x41..0x5A || s in 0x61..0x7A || s in '.-')
    end)
    |> Kernel.!()
  end

  def match_mention(buffer) do
    case Regex.run(~r/^@(?<user>[a-zA-Z\d_-]+)(@(?<host>[^@]+))?$/, buffer,
           capture: [:user, :host]
         ) do
      [user, ""] ->
        "@" <> user

      [user, hostname] ->
        if valid_hostname?(hostname) && valid_tld?(hostname, []),
          do: "@" <> user <> "@" <> hostname,
          else: nil

      _ ->
        nil
    end
  end

  def match_hashtag(buffer) do
    case Regex.run(@match_hashtag, buffer, capture: [:tag]) do
      [hashtag] -> hashtag
      _ -> nil
    end
  end

  @doc false
  def link_url(url, buffer, %{url_handler: url_handler} = opts, user_acc) do
    url
    |> url_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(url, buffer)
  end

  @doc false
  def link_email(buffer, %{email_handler: email_handler} = opts, user_acc) do
    buffer
    |> email_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(buffer, buffer)
  end

  def link_hashtag(nil, _buffer, _, _user_acc), do: :nomatch

  def link_hashtag(hashtag, buffer, %{hashtag_handler: hashtag_handler} = opts, user_acc) do
    hashtag
    |> hashtag_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(hashtag, buffer)
  end

  def link_mention(nil, _buffer, _, _user_acc), do: :nomatch

  def link_mention(mention, buffer, %{mention_handler: mention_handler} = opts, user_acc) do
    mention
    |> mention_handler.(buffer, opts, user_acc)
    |> maybe_update_buffer(mention, buffer)
  end

  defp maybe_update_buffer(out, match, buffer) when is_binary(out) do
    maybe_update_buffer({out, nil}, match, buffer)
  end

  defp maybe_update_buffer({out, user_acc}, match, buffer)
       when match != buffer and out != buffer do
    out = String.replace(buffer, match, out)
    {out, user_acc}
  end

  defp maybe_update_buffer(out, _match, _buffer), do: out

  defp link(buffer, opts, user_acc) do
    Enum.reduce_while(@types, {buffer, user_acc}, fn type, _ ->
      if opts[type] == true do
        check_and_link_reducer(type, buffer, opts, user_acc)
      else
        {:cont, {buffer, user_acc}}
      end
    end)
  end

  defp check_and_link_reducer(type, buffer, opts, user_acc) do
    str =
      buffer
      |> String.split("<")
      |> List.first()
      |> strip_en_apostrophes()
      |> strip_punctuation()
      |> maybe_strip_parens()

    case check_and_link(type, str, opts, user_acc) do
      :nomatch ->
        {:cont, {buffer, user_acc}}

      {link, user_acc} ->
        {:halt, {restore_stripped_symbols(buffer, str, link), user_acc}}

      link ->
        {:halt, {restore_stripped_symbols(buffer, str, link), user_acc}}
    end
  end

  defp restore_stripped_symbols(buffer, buffer, link), do: link

  defp restore_stripped_symbols(buffer, stripped_buffer, link) do
    buffer
    |> String.split(stripped_buffer)
    |> Enum.intersperse(link)
  end

  def url_handler(url, buffer, opts, %{markdown_hrefs: markdown_hrefs} = user_acc) do
    if Enum.member?(markdown_hrefs, url) do
      Logger.debug("ignoring markdown url #{url}")
      {buffer, user_acc}
    else
      out = "[#{url}](#{url})"

      item = %{href: url, name: url}
      user_acc = Map.update(user_acc, :urls, [item], fn acc -> [item | acc] end)

      {out, user_acc}
    end
  end

  def email_handler(email, buffer, opts, user_acc) do
    url = "mailto:#{email}"
    out = "[#{email}](#{url})"

    item = %{href: url, name: email}
    user_acc = Map.update(user_acc, :emails, [item], fn acc -> [item | acc] end)

    {out, user_acc}
  end

  def mention_handler(
        mention,
        buffer,
        opts,
        %{endpoint_uri: %URI{host: host} = endpoint_uri} = user_acc
      ) do
    url =
      case mention |> String.replace_leading("@", "") |> String.split("@") do
        [nickname] ->
          Utils.base_uri(endpoint_uri, "/users/#{nickname}") |> URI.to_string()

        [nickname | domain] ->
          if domain == host do
            Utils.base_uri(endpoint_uri, "/users/#{nickname}") |> URI.to_string()
          else
            case FediServerWeb.WebFinger.finger(mention) do
              {:ok, %{"ap_id" => ap_id}} -> ap_id
              _ -> nil
            end
          end
      end

    if is_nil(url) do
      {buffer, user_acc}
    else
      out = "[#{mention}](#{url})"
      item = %{href: url, name: mention}
      user_acc = Map.update(user_acc, :mentions, [item], fn acc -> [item | acc] end)

      {out, user_acc}
    end
  end

  def hashtag_handler(
        hashtag,
        buffer,
        opts,
        %{endpoint_uri: %URI{path: path} = endpoint_uri} = user_acc
      ) do
    tag = hashtag |> String.replace_leading("#", "")
    url = Utils.base_uri(endpoint_uri, "/hashtags/#{tag}") |> URI.to_string()

    out = "[#{hashtag}](#{url})"
    item = %{href: url, name: hashtag}
    user_acc = Map.update(user_acc, :hashtags, [item], fn acc -> [item | acc] end)

    {out, user_acc}
  end
end
