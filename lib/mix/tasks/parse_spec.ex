defmodule Mix.Tasks.ParseSpec do
  @shortdoc "Parses jsonld file"

  use Mix.Task

  @impl true
  def run(argv) do
    case argv do
      [] ->
        Mix.raise("Expected PATH to be given, please use \"mix as.parse PATH\"")

      files ->
        data = %{
          types: %{},
          properties: %{}
        }

        files
        |> Enum.reduce(data, fn filename, data -> parse_file(filename, data) end)
        |> summarize()
    end
  end

  def summarize(data) do
    properties_by_range =
      Enum.reduce(data[:properties], %{}, fn {name, %{namespace: namespace, range: range}}, acc ->
        case range do
          r when is_list(r) ->
            range_key = Enum.join(r, ", ")
            prop_name = "#{namespace}:#{name}"
            Map.update(acc, range_key, [prop_name], fn props -> [prop_name | props] end)

          _ ->
            acc
        end
      end)

    range_keys = Map.keys(properties_by_range) |> Enum.sort()

    Enum.each(range_keys, fn range_key ->
      IO.puts("\nRange #{range_key}")

      properties_by_range
      |> Map.get(range_key)
      |> Enum.sort()
      |> Enum.each(fn prop -> IO.puts(" #{prop}") end)
    end)
  end

  def parse_file(filename, data) do
    path = :code.priv_dir(:activity_streams) |> Path.join(filename)

    with {:ok, body} <- File.read(path),
         {:ok, contents} <- Jason.decode(body) do
      namespace = contents["name"]
      data = contents["sections"] |> parse_sections(namespace, data)
      contents["members"] |> parse_members(namespace, data)
    else
      error ->
        IO.inspect(error, label: "parse_file #{filename}")
        data
    end
  end

  def parse_sections(sections, namespace, data) when is_map(sections) do
    Enum.reduce(sections, data, fn {k, v}, data ->
      IO.puts("\nSection #{k}")
      v["members"] |> parse_members(namespace, data)
    end)
  end

  def parse_sections(_, _, data), do: data

  def parse_members(members, namespace, data) when is_list(members) do
    Enum.reduce(members, data, fn member, acc -> parse_member(member, namespace, acc) end)
  end

  def parse_members(_, _, data), do: data

  def parse_member(member, namespace, data) when is_map(member) do
    name = member["name"] |> String.replace_leading("as:", "")
    types = member["type"] |> List.wrap()

    cond do
      Enum.member?(types, "rdf:Property") ->
        parse_property(member, name, namespace, data)

      Enum.member?(types, "owl:Class") ->
        parse_type(member, name, namespace, data)

      true ->
        types = Enum.join(types, ", ")
        IO.puts("Unrecognized type #{types} for #{name}")
        data
    end
  end

  def parse_property(member, name, namespace, data) do
    IO.puts("\nProperty #{name}")
    {parents, parents_str} = refs(member, "subPropertyOf")

    if parents do
      IO.puts(" parent properties: #{parents_str}")
    end

    {domain, domain_str} = refs(member["domain"], "unionOf")

    if domain do
      IO.puts(" domain #{domain_str}")
    end

    {range_, range_str} = refs(member["range"], "unionOf")

    if range_ do
      IO.puts(" range #{range_str}")
    end

    Map.update!(data, :properties, fn properties ->
      Map.put(properties, name, %{
        namespace: namespace,
        parents: parents,
        domain: domain,
        range: range_
      })
    end)
  end

  def parse_type(member, name, namespace, data) do
    IO.puts("\nType #{name}")
    {parents, parents_str} = refs(member, "subClassOf")

    if parents do
      IO.puts(" parent types: #{parents_str}")
    end

    {disjoint_with, disjoint_with_str} = refs(member, "disjointWith")
    IO.puts(" disjoint with: [#{disjoint_with_str}]")

    Map.update!(data, :types, fn types ->
      Map.put(types, name, %{namespace: namespace, parents: parents, disjoint_with: disjoint_with})
    end)
  end

  def refs(item, relation) do
    case item[relation] do
      nil ->
        {nil, ""}

      rel ->
        items =
          rel
          |> List.wrap()
          |> Enum.map(fn
            ref when is_map(ref) -> ref["name"] |> String.replace_leading("as:", "")
            ref when is_binary(ref) -> ref |> String.replace_leading("as:", "")
          end)
          |> Enum.sort()

        {items, Enum.join(items, ", ")}
    end
  end
end
