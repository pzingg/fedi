defmodule Mix.Tasks.Ontology.Gen do
  @moduledoc """
  Parses the ontology stored in ActivityStreams-related .jsonld files and
  produces .ex modules for the types and properties it finds.

  See https://go-fed/activity for more information on these .jsonld files.

      $ mix ontology.gen FILE_GLOB [FILE_GLOB]+

  Where a FILE_GLOB is usually `*.jsonld`.  If no absolute path is specifed in
  the FILE_GLOBs, the files will be globbed from the `priv` directory.
  """

  use Mix.Task

  @output_dir "./_docs"
  @file_ext ".ex"

  defmodule Property do
    defstruct [
      :namespace,
      :section,
      :name,
      :typedoc,
      nonfunctional?: false,
      functional?: false,
      object?: false,
      range: [],
      range_set: [],
      extends: [],
      extended_by: [],
      types: [],
      base_domain: [],
      except_domain: [],
      extended_domain: []
    ]
  end

  defmodule Value do
    defstruct [
      :namespace,
      :section,
      :name,
      :typedoc,
      typeless?: false,
      extends: [],
      extended_by: [],
      disjoint_with: []
    ]
  end

  defmodule Ontology do
    defstruct namespaces: %{},
              values: [],
              properties: []
  end

  @impl true
  def run(argv) do
    case argv do
      [] ->
        Mix.raise("Expected FILE_GLOB to be given, please use \"mix ontology.gen FILE_GLOB\"")

      files ->
        ontology = parse_files(files, %Ontology{})

        output_templates(ontology)
        # dump(ontology, "#{@output_dir}/ontology.json")
    end
  end

  def dump(%{values: values, properties: properties} = ontology, filename) do
    values = Enum.map(values, fn val -> Map.from_struct(val) end)
    properties = Enum.map(properties, fn prop -> Map.from_struct(prop) end)

    content = Jason.encode!(%{values: values, properties: properties}, pretty: true)
    File.write(filename, content)

    ontology
  end

  def parse_files(globs, ontology) do
    paths =
      globs
      |> Enum.map(fn glob ->
        if String.starts_with?(glob, "/") do
          Path.wildcard(glob)
        else
          Path.join(:code.priv_dir(:fedi), glob) |> Path.wildcard()
        end
      end)
      |> List.flatten()

    ontology = Enum.reduce(paths, ontology, fn path, acc -> parse_file(path, acc) end)

    values =
      Enum.reverse(ontology.values)
      |> map_extended_by()

    properties =
      Enum.reverse(ontology.properties)
      |> map_extended_by()
      |> extend_domains(values)

    %Ontology{ontology | properties: properties, values: values}
  end

  def parse_file(path, ontology) do
    with {:ok, body} <- File.read(path),
         {:ok, contents} <- Jason.decode(body) do
      namespace = contents["name"]
      ontology = contents["sections"] |> parse_sections(namespace, ontology)
      contents["members"] |> parse_members(namespace, "", ontology)
    else
      error ->
        Mix.shell().error("File error #{inspect(error)}")
        ontology
    end
  end

  def parse_sections(sections, namespace, ontology) when is_map(sections) do
    Enum.reduce(sections, ontology, fn {section, v}, ontology ->
      v["members"] |> parse_members(namespace, section, ontology)
    end)
  end

  def parse_sections(_, _, ontology), do: ontology

  def parse_members(members, namespace, section, ontology) when is_list(members) do
    Enum.reduce(members, ontology, fn member, acc ->
      parse_member(member, namespace, section, acc)
    end)
  end

  def parse_members(_, _, _, ontology), do: ontology

  def parse_member(member, namespace, section, ontology) when is_map(member) do
    name = member["name"] |> String.replace_leading("as:", "")
    types = member["type"] |> List.wrap()

    cond do
      Enum.member?(types, "rdf:Property") ->
        parse_property(member, name, namespace, section, ontology)

      Enum.member?(types, "owl:Class") ->
        parse_type(member, name, namespace, section, ontology)

      true ->
        types = Enum.join(types, ", ")
        Mix.shell().error("Unrecognized type #{types} for #{name}")
        ontology
    end
  end

  def parse_property(member, name, namespace, section, ontology) do
    {types, _} = refs(member, "type")
    {extends, _} = refs(member, "subPropertyOf")
    {domain, _} = refs(member["domain"], "unionOf")
    {except_domain, _} = refs(member, "@wtf_without_property")
    {range_, _} = refs(member["range"], "unionOf")

    object? = "owl:ObjectProperty" in types
    functional? = "owl:FunctionalProperty" in types

    range_set =
      []
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> !String.contains?(r, ":") end),
        [:object, :iri]
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:anyURI") end),
        :any_uri
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "rdf:langString") end),
        [:string, :lang_string]
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:String") end),
        :string
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:boolean") end),
        :boolean
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:nonNegativeInteger") end),
        :non_neg_integer
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:float") end),
        :float
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:dateTime") end),
        :date_time
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:duration") end),
        :duration
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "rfc:bcp47") end),
        :bcp47
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "rfc:rfc2045") end),
        :rfc2045
      )
      |> add_range_flag_if(
        Enum.any?(range_, fn r -> String.contains?(r, "rfc:rfc5988") end),
        :rfc5988
      )
      |> MapSet.new()
      |> MapSet.to_list()

    property = %Property{
      namespace: namespace,
      section: section,
      name: name,
      typedoc: ref(member, "notes", "The #{namespace} \"#{name}\" property."),
      nonfunctional?: !functional?,
      functional?: functional?,
      object?: object?,
      range: range_,
      range_set: range_set,
      extends: extends,
      types: types,
      base_domain: domain,
      except_domain: except_domain,
      extended_domain: []
    }

    %Ontology{ontology | properties: [property | ontology.properties]}
  end

  def add_range_flag_if(range_set, true, flag) when is_list(flag), do: flag ++ range_set
  def add_range_flag_if(range_set, true, flag), do: [flag | range_set]
  def add_range_flag_if(range_set, _, _), do: range_set

  def parse_type(member, name, namespace, section, ontology) do
    {extends, _} = refs(member, "subClassOf")
    {disjoint_with, _} = refs(member, "disjointWith")
    typeless? = Map.get(member, "@wtf_typeless")

    value = %Value{
      namespace: namespace,
      section: section,
      name: name,
      typedoc: ref(member, "notes", "The #{namespace} \"#{name}\" type."),
      typeless?: typeless?,
      extends: extends,
      disjoint_with: disjoint_with,
      extended_by: []
    }

    %Ontology{ontology | values: [value | ontology.values]}
  end

  def ref(item, relation, default \\ nil) do
    case refs(item, relation) do
      {[single], _} -> single
      _ -> default
    end
  end

  def refs(item, relation) do
    case item[relation] do
      nil ->
        {[], ""}

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

  def map_extended_by(coll) do
    initial_map =
      coll
      |> Enum.map(&parent_and_child/1)
      |> Enum.reduce(%{}, &parents_by_child/2)

    extended_map =
      Enum.map(initial_map, fn {child, parents} ->
        all_ancestors =
          Enum.reduce(parents, parents, fn parent, acc ->
            acc ++ Map.get(initial_map, parent, [])
          end)

        {child, all_ancestors}
      end)
      |> Map.new()

    Enum.map(coll, fn %{name: name, extended_by: _} = item ->
      extended_by = Map.get(extended_map, name, [])
      struct(item, extended_by: extended_by)
    end)
  end

  def parent_and_child(%{name: name, extends: extends}) do
    {name, extends}
  end

  def parents_by_child({parent, children}, acc) do
    Enum.reduce(children, acc, fn child, acc2 ->
      Map.update(acc2, child, [parent], fn parents -> [parent | parents] end)
    end)
  end

  def extend_domains(properties, values) do
    Enum.map(
      properties,
      fn %Property{
           base_domain: base_domain,
           except_domain: except_domain
         } = item ->
        domain =
          Enum.reduce(values, base_domain, fn %{name: value_name, extended_by: value_extended_by},
                                              acc ->
            if Enum.member?(base_domain, value_name) do
              acc ++ value_extended_by
            else
              acc
            end
          end)

        domain =
          case except_domain do
            [] ->
              MapSet.new(domain)

            some ->
              MapSet.new(domain) |> MapSet.difference(MapSet.new(some))
          end
          |> MapSet.to_list()

        %Property{item | extended_domain: domain}
      end
    )
  end

  ##### Outputting templates

  def output_templates(ontology) do
    Enum.each(ontology.properties, fn prop ->
      prop = prepare_for_template(prop)

      cond do
        prop[:nonfunctional?] ->
          prop_iterator(prop)
          prop_iterating(prop)

        prop[:functional?] || prop[:object?] ->
          prop_functional(prop)

        true ->
          :ok
      end
    end)
  end

  def prepare_for_template(prop) do
    {defstruct_members, type_members} =
      if Enum.member?(prop.range_set, :any_uri) do
        {[":xsd_any_uri_member"], ["xsd_any_uri_member: URI.t() | nil"]}
      else
        {[":iri"], ["iri: URI.t() | nil"]}
      end

    {defstruct_members, type_members} =
      {defstruct_members, type_members}
      |> add_members_if(prop.range_set, :object, [":member"], [
        "member: term()"
      ])
      |> add_members_if(prop.range_set, :lang_string, [":rdf_lang_string_member"], [
        "rdf_lang_string_member: map() | nil"
      ])
      |> add_members_if(
        prop.range_set,
        :string,
        [":xsd_string_member", "has_string_member?: false"],
        [
          "xsd_string_member: String.t() | nil",
          "has_string_member?: boolean()"
        ]
      )
      |> add_members_if(
        prop.range_set,
        :boolean,
        [":xsd_boolean_member", "has_boolean_member?: false"],
        ["xsd_boolean_member: boolean() | nil", "has_boolean_member?: boolean()"]
      )
      |> add_members_if(
        prop.range_set,
        :non_neg_integer,
        [":xsd_non_neg_integer_member", "has_non_neg_integer_member?: false"],
        [
          "xsd_non_neg_integer_member: non_neg_integer() | nil",
          "has_non_neg_integer_member?: boolean()"
        ]
      )
      |> add_members_if(
        prop.range_set,
        :float,
        [":xsd_float_member", "has_float_member?: false"],
        [
          "xsd_float_member: float() | nil",
          "has_float_member?: boolean()"
        ]
      )
      |> add_members_if(
        prop.range_set,
        :date_time,
        [":xsd_date_time_member", "has_date_time_member?: false"],
        ["xsd_date_time_member: DateTime.t() | nil", "has_date_time_member?: boolean()"]
      )
      |> add_members_if(
        prop.range_set,
        :duration,
        [":xsd_duration_member", "has_duration_member?: false"],
        [
          "xsd_duration_member: Timex.Duration.t() | nil",
          "has_duration_member?: boolean()"
        ]
      )
      |> add_members_if(
        prop.range_set,
        :bcp47,
        [":rfc_bcp47_member", "has_bcp47_member?: false"],
        [
          "rfc_bcp47_member: String.t() | nil",
          "has_bcp47_member?: boolean()"
        ]
      )
      |> add_members_if(
        prop.range_set,
        :rfc2045,
        [":rfc_rfc2045_member", "has_rfc2045_member?: false"],
        ["rfc_rfc2045_member: String.t() | nil", "has_rfc2045_member?: boolean()"]
      )
      |> add_members_if(
        prop.range_set,
        :rfc5988,
        [":rfc_rfc5988_member", "has_rfc5988_member?: false"],
        ["rfc_rfc5988_member: String.t() | nil", "has_rfc5988_member?: boolean()"]
      )

    defstruct_members =
      case defstruct_members do
        [] ->
          []

        _ ->
          [last | prev] =
            Enum.sort(defstruct_members, fn a, _b -> String.ends_with?(a, ": false") end)

          lines =
            [last | Enum.map(prev, fn line -> line <> "," end)]
            |> Enum.reverse()

          ["," | lines]
      end

    type_members =
      case type_members do
        [] ->
          []

        [last | prev] ->
          lines =
            [last | Enum.map(prev, fn line -> line <> "," end)]
            |> Enum.reverse()

          ["," | lines]
      end

    {prop_names, defstruct_mapped, typet_mapped} =
      if Enum.member?(prop.range_set, :lang_string) do
        {
          "[\"#{prop.name}\", \"#{prop.name}Map\"]",
          [",", "mapped_values: []"],
          [",", "mapped_values: list()"]
        }
      else
        {"\"#{prop.name}\"", [], []}
      end

    member_types =
      prop.range_set
      |> Enum.map(fn atom -> ":#{Atom.to_string(atom)}" end)
      |> Enum.join(", ")

    prop = Map.from_struct(prop) |> Enum.into([])

    Keyword.merge(prop,
      defstruct: indent_lines(defstruct_members, 4),
      defstruct_mapped: indent_lines(defstruct_mapped, 4),
      typet: indent_lines(type_members, 10),
      typet_mapped: indent_lines(typet_mapped, 10),
      typedoc: wrap_text(prop[:typedoc], 2, 78),
      ns_atom: Macro.underscore(prop[:namespace]),
      member_types: "[#{member_types}]",
      names: prop_names
    )
  end

  def add_members_if({d_mem, t_mem}, set, member, d_add, t_add) do
    if Enum.member?(set, member) do
      {d_mem ++ d_add, t_mem ++ t_add}
    else
      {d_mem, t_mem}
    end
  end

  def indent_lines([], _), do: ""

  def indent_lines([first | rest], indent) do
    indent = String.duplicate(" ", indent)

    [first | Enum.map(rest, fn line -> indent <> line end)]
    |> Enum.join("\n")
  end

  def wrap_text(text, indent, cols) do
    if String.length(text) < cols do
      text
    else
      {lines, word} =
        String.split(text, " ")
        |> Enum.reduce({[], ""}, fn word, {lines, current_line} ->
          if current_line == "" do
            {lines, word}
          else
            added = current_line <> " " <> word

            if String.length(added) <= cols do
              {lines, added}
            else
              {[current_line | lines], word}
            end
          end
        end)

      case lines do
        [] ->
          word

        [last_line | ls] ->
          added = last_line <> " " <> word

          [first | ls] =
            if String.length(added) <= cols do
              [added | ls] |> Enum.reverse()
            else
              [word | lines] |> Enum.reverse()
            end

          indent = String.duplicate(" ", indent)

          [first | Enum.map(ls, fn line -> indent <> line end)]
          |> Enum.join("\n")
      end
    end
  end

  def capitalize(str) do
    {head, rest} = String.split_at(str, 1)
    String.upcase(head) <> rest
  end

  def render_file(template, data, dir, filename) do
    contents = EEx.eval_string(template, data)

    dir = Path.join(@output_dir, dir)
    File.mkdir_p(dir)

    Path.join(dir, filename)
    |> File.write(contents)
  end

  def prop_functional(prop) do
    dir = Path.join(prop[:ns_atom], "property")
    filename = Macro.underscore(prop[:name]) <> @file_ext
    mod_name = capitalize(prop[:name])
    module = "Fedi.#{prop[:namespace]}.Property.#{mod_name}"
    data = [prop: prop, q3: "\"\"\"", module: module]

    """
    defmodule <%= module %> do
      # This module was generated from an ontology. DO NOT EDIT!
      # Run `mix help ontology.gen` for details.

      @moduledoc <%= q3 %>
      <%= prop[:typedoc] %>
      <%= q3 %>

      @namespace :<%= prop[:ns_atom] %>
      @member_types <%= prop[:member_types] %>
      @prop_name <%= prop[:names] %>

      @enforce_keys [:alias]
      defstruct [
        :alias,
        :unknown<%= prop[:defstruct] %>
      ]

      @type t() :: %__MODULE__{
              alias: String.t(),
              unknown: term()<%= prop[:typet] %>
            }

      def new(alias_ \\\\ "") do
        %__MODULE__{alias: alias_}
      end

      def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
        Fedi.Streams.BaseProperty.deserialize(
          @namespace,
          __MODULE__,
          @member_types,
          @prop_name,
          m,
          alias_map
        )
      end

      def serialize(%__MODULE__{} = prop) do
        Fedi.Streams.BaseProperty.serialize(prop)
      end
    end
    """
    |> render_file(data, dir, filename)
  end

  def prop_iterating(prop) do
    dir = Path.join(prop[:ns_atom], "property")
    filename = Macro.underscore(prop[:name]) <> @file_ext
    mod_name = capitalize(prop[:name])
    module = "Fedi.#{prop[:namespace]}.Property.#{mod_name}"
    data = [prop: prop, q3: "\"\"\"", module: module]

    """
    defmodule <%= module %> do
      # This module was generated from an ontology. DO NOT EDIT!
      # Run `mix help ontology.gen` for details.

      @moduledoc <%= q3 %>
      <%= prop[:typedoc] %>
      <%= q3 %>

      @namespace :<%= prop[:ns_atom] %>
      @prop_name <%= prop[:names] %>

      @enforce_keys :alias
      defstruct [
        :alias,
        values: []<%= prop[:defstruct_mapped] %>
      ]

      @type t() :: %__MODULE__{
              alias: String.t(),
              values: list()<%= prop[:typet_mapped] %>
            }

      def new(alias_ \\\\ "") do
        %__MODULE__{alias: alias_}
      end

      def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
        Fedi.Streams.BaseProperty.deserialize_values(
          @namespace,
          __MODULE__,
          @prop_name,
          m,
          alias_map
        )
      end

      def serialize(%__MODULE__{} = prop) do
        Fedi.Streams.BaseProperty.serialize(prop)
      end
    end
    """
    |> render_file(data, dir, filename)
  end

  def prop_iterator(prop) do
    dir = Path.join(prop[:ns_atom], "property")
    filename = Macro.underscore(prop[:name]) <> "_iterator" <> @file_ext
    mod_name = capitalize(prop[:name]) <> "Iterator"
    module = "Fedi.#{prop[:namespace]}.Property.#{mod_name}"
    data = [prop: prop, q3: "\"\"\"", module: module]

    """
    defmodule <%= module %> do
      # This module was generated from an ontology. DO NOT EDIT!
      # Run `mix help ontology.gen` for details.

      @moduledoc <%= q3 %>
      Iterator for the <%= prop[:namespace] %> "<%= prop[:name] %>" property.
      <%= q3 %>

      @namespace :<%= prop[:ns_atom] %>
      @member_types <%= prop[:member_types] %>

      @enforce_keys [:alias]
      defstruct [
        :alias,
        :unknown<%= prop[:defstruct] %>
      ]

      @type t() :: %__MODULE__{
              alias: String.t(),
              unknown: term()<%= prop[:typet] %>
            }

      def new(alias_ \\\\ "") do
        %__MODULE__{alias: alias_}
      end

      def deserialize(prop_name, mapped_property?, i, alias_map) when is_map(alias_map) do
        Fedi.Streams.PropertyIterator.deserialize(
          @namespace,
          __MODULE__,
          @member_types,
          prop_name,
          mapped_property?,
          i,
          alias_map
        )
      end

      def serialize(%__MODULE__{} = prop) do
        Fedi.Streams.BaseProperty.serialize(prop)
      end
    end
    """
    |> render_file(data, dir, filename)
  end
end
