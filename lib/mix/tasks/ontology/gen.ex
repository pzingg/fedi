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

  defmodule Type do
    defstruct [
      :namespace,
      :section,
      :name,
      :typedoc,
      typeless?: false,
      extends: [],
      extended_by: [],
      disjoint_with: [],
      properties: []
    ]
  end

  defmodule Ontology do
    defstruct namespaces: %{},
              types: [],
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

  def dump(%{types: types, properties: properties} = ontology, filename) do
    types = Enum.map(types, fn val -> Map.from_struct(val) end)
    properties = Enum.map(properties, fn prop -> Map.from_struct(prop) end)

    content = Jason.encode!(%{types: types, properties: properties}, pretty: true)
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

    types =
      Enum.reverse(ontology.types)
      |> map_extended_by()
      |> map_extends()
      |> extend_disjoint_with()

    properties =
      Enum.reverse(ontology.properties)
      |> map_extended_by()
      |> extend_domains(types)

    properties_by_type = inverted_domains(properties)

    types =
      Enum.map(types, fn %Type{name: name} = type ->
        new_props = Map.get(properties_by_type, name, [])
        %Type{type | properties: new_props}
      end)

    %Ontology{ontology | properties: properties, types: types}
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
    # |> String.replace_leading("as:", "")
    name = member["name"]
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
        Enum.any?(range_, fn r -> String.contains?(r, "xsd:string") end),
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

    type = %Type{
      namespace: namespace,
      section: section,
      name: name,
      typedoc: ref(member, "notes", "The #{namespace} \"#{name}\" type."),
      typeless?: typeless?,
      extends: extends,
      disjoint_with: disjoint_with
    }

    %Ontology{ontology | types: [type | ontology.types]}
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
            # |> String.replace_leading("as:", "")
            ref when is_map(ref) -> ref["name"]
            # |> String.replace_leading("as:", "")
            ref when is_binary(ref) -> ref
          end)
          |> Enum.sort()

        {items, Enum.join(items, ", ")}
    end
  end

  def map_extended_by(coll) do
    initial_map =
      coll
      |> Enum.map(fn %{name: name, extends: extends} -> {name, extends} end)
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

  def map_extends(types) do
    initial_map =
      types
      |> Enum.reduce([], fn %{name: name, extends: extends}, acc ->
        acc ++ Enum.map(extends, fn parent -> {name, parent} end)
      end)
      |> Enum.into(%{})

    types
    |> Enum.map(fn %Type{extends: extends} = type ->
      new_extends = extends ++ all_extends(initial_map, extends, [])
      new_extends = MapSet.new(new_extends) |> MapSet.to_list()
      %Type{type | extends: new_extends}
    end)
  end

  def all_extends(initial_map, extends, acc) do
    Enum.reduce(extends, acc, fn type_name, acc2 ->
      case Map.get(initial_map, type_name) do
        nil ->
          acc2

        parent ->
          ancestors = all_extends(initial_map, [parent], acc2)
          [parent | ancestors]
      end
    end)
  end

  def parents_by_child({parent, children}, acc) do
    Enum.reduce(children, acc, fn child, acc2 ->
      Map.update(acc2, child, [parent], fn parents -> [parent | parents] end)
    end)
  end

  def extend_disjoint_with(types) do
    dw_map =
      Enum.map(types, fn %Type{name: name, disjoint_with: disjoint_with} ->
        if Enum.empty?(disjoint_with) do
          nil
        else
          {name, disjoint_with}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})

    eb_map =
      Enum.map(types, fn %Type{name: name, extended_by: extended_by} ->
        {name, extended_by}
      end)
      |> Enum.into(%{})

    dw_keys = Map.keys(dw_map)

    base_map =
      Enum.reduce(types, [], fn %Type{name: name, extended_by: extended_by}, acc ->
        if Enum.member?(dw_keys, name) do
          acc ++ Enum.map(extended_by, fn child -> {child, name} end)
        else
          acc
        end
      end)
      |> Enum.into(%{})

    Enum.map(types, fn %Type{name: name} = type ->
      base_type = Map.get(base_map, name, name)

      case Map.get(dw_map, base_type, []) do
        [] ->
          type

        base_dws ->
          extended_dw =
            Enum.reduce(base_dws, [], fn base_dw, acc ->
              acc ++ [base_dw | Map.get(eb_map, base_dw, [])]
            end)

          %Type{type | disjoint_with: extended_dw}
      end
    end)
  end

  def extend_domains(properties, types) do
    Enum.map(
      properties,
      fn %Property{
           base_domain: base_domain,
           except_domain: except_domain
         } = item ->
        domain =
          Enum.reduce(types, base_domain, fn %Type{
                                               name: value_name,
                                               extended_by: value_extended_by
                                             },
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
    output_properties(ontology.properties)
    output_types(ontology.types)
  end

  def output_properties(properties) do
    Enum.each(properties, fn prop ->
      prop = prepare_property(prop)

      cond do
        prop[:nonfunctional?] ->
          render_iterator_prop(prop)
          render_non_functional_prop(prop)

        prop[:functional?] || prop[:object?] ->
          render_functional_prop(prop)

        true ->
          :ok
      end
    end)
  end

  def output_types(types) do
    Enum.each(types, fn type ->
      type = prepare_type(type)
      render_type(type)
    end)
  end

  def prepare_property(prop) do
    {defstruct_members, type_members} =
      if Enum.member?(prop.range_set, :any_uri) do
        {[":xsd_any_uri_member"], ["xsd_any_uri_member: URI.t() | nil"]}
      else
        {[":iri"], ["iri: URI.t() | nil"]}
      end

    {defstruct_members, type_members} =
      {defstruct_members, type_members}
      |> add_members_if(prop.range_set, :object, [":member"], ["member: term()"])
      |> add_members_if(
        prop.range_set,
        :lang_string,
        [":rdf_lang_string_member"],
        ["rdf_lang_string_member: map() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :string,
        [":xsd_string_member"],
        ["xsd_string_member: String.t() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :boolean,
        [":xsd_boolean_member"],
        ["xsd_boolean_member: boolean() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :non_neg_integer,
        [":xsd_non_neg_integer_member"],
        ["xsd_non_neg_integer_member: non_neg_integer() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :float,
        [":xsd_float_member"],
        ["xsd_float_member: float() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :date_time,
        [":xsd_date_time_member"],
        ["xsd_date_time_member: DateTime.t() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :duration,
        [":xsd_duration_member"],
        ["xsd_duration_member: Timex.Duration.t() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :bcp47,
        [":rfc_bcp47_member"],
        ["rfc_bcp47_member: String.t() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :rfc2045,
        [":rfc_rfc2045_member"],
        ["rfc_rfc2045_member: String.t() | nil"]
      )
      |> add_members_if(
        prop.range_set,
        :rfc5988,
        [":rfc_rfc5988_member"],
        ["rfc_rfc5988_member: String.t() | nil"]
      )

    # Enum.sort(defstruct_members, fn a, _b -> String.ends_with?(a, ": false") end)

    defstruct_members = concat_members(defstruct_members)
    type_members = concat_members(type_members)

    {prop_names, defstruct_mapped, typet_mapped} =
      if Enum.member?(prop.range_set, :lang_string) do
        {
          "[\"#{prop.name}\", \"#{prop.name}Map\"]",
          [",", "mapped_values: []"],
          [",", "mapped_values: list()"]
        }
      else
        {enquote(prop.name), [], []}
      end

    range =
      prop.range_set
      |> Enum.map(fn atom -> ":#{Atom.to_string(atom)}" end)
      |> Enum.join(", ")

    # TODO: "as:" namespace
    domain =
      prop.extended_domain
      |> Enum.map(fn type_name -> quote_type_and_module(type_name, prop.namespace) end)
      |> Enum.sort(:desc)
      |> concat_members(nil)

    prop = Map.from_struct(prop) |> Enum.into([])

    Keyword.merge(prop,
      defstruct: indent_lines(defstruct_members, 4),
      defstruct_mapped: indent_lines(defstruct_mapped, 4),
      typet: indent_lines(type_members, 10),
      typet_mapped: indent_lines(typet_mapped, 10),
      typedoc: wrap_text(prop[:typedoc], 2, 78),
      ns_atom: Macro.underscore(prop[:namespace]),
      range: "[#{range}]",
      domain: indent_lines(domain, 4),
      names: prop_names
    )
  end

  def quote_type_and_module(type_name, namespace) do
    if String.starts_with?(type_name, "as:") do
      type_name = String.replace_leading(type_name, "as:", "")
      "{\"#{type_name}\", Fedi.ActivityStreams.Type.#{type_name}}"
    else
      "{\"#{type_name}\", Fedi.#{namespace}.Type.#{type_name}}"
    end
  end

  def add_members_if({d_mem, t_mem}, set, member, d_add, t_add) do
    if Enum.member?(set, member) do
      {d_mem ++ d_add, t_mem ++ t_add}
    else
      {d_mem, t_mem}
    end
  end

  def concat_members(members, prefix \\ ",")

  def concat_members([], _prefix), do: []

  def concat_members([last | prev], prefix) do
    lines =
      [last | Enum.map(prev, fn line -> line <> "," end)]
      |> Enum.reverse()

    if prefix do
      [prefix | lines]
    else
      lines
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

  def prepare_type(type) do
    is_or_extends =
      type.extends
      |> Enum.map(&enquote(&1))
      |> Enum.sort(:desc)

    is_or_extends =
      (is_or_extends ++ [enquote(type.name)])
      |> concat_members(nil)

    disjoint_with =
      type.disjoint_with
      |> Enum.map(&enquote(&1))
      |> Enum.sort(:desc)
      |> concat_members(nil)

    extended_by =
      type.extended_by
      |> Enum.map(&enquote(&1))
      |> Enum.sort(:desc)
      |> concat_members(nil)

    properties =
      type.properties
      |> Enum.map(&enquote(&1))
      |> Enum.sort(:desc)
      |> concat_members(nil)

    type = Map.from_struct(type) |> Enum.into([])

    Keyword.merge(type,
      typedoc: wrap_text(type[:typedoc], 2, 78),
      ns_atom: Macro.underscore(type[:namespace]),
      disjoint_with: indent_lines(disjoint_with, 4),
      extended_by: indent_lines(extended_by, 4),
      is_or_extends: indent_lines(is_or_extends, 4),
      properties: indent_lines(properties, 4)
    )
  end

  def enquote(s) do
    s = String.replace_leading(s, "as:", "")
    "\"#{s}\""
  end

  def inverted_domains(properties) do
    Enum.reduce(properties, [], fn prop, acc ->
      elems =
        if Enum.member?(prop.range_set, :lang_string) do
          Enum.map(prop.extended_domain, fn type_name ->
            [{type_name, prop.name}, {type_name, "#{prop.name}Map"}]
          end)
          |> List.flatten()
        else
          Enum.map(prop.extended_domain, fn type_name -> {type_name, prop.name} end)
        end

      acc ++ elems
    end)
    |> Enum.sort()
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.map(fn [{type_name, _prop_name} | _] = prop_list ->
      {type_name, Enum.map(prop_list, &elem(&1, 1)) |> Enum.sort()}
    end)
    |> Enum.into(%{})
  end

  def render_type(type) do
    dir = Path.join(type[:ns_atom], "type")
    filename = Macro.underscore(type[:name]) <> @file_ext
    module = "Fedi.#{type[:namespace]}.Type.#{type[:name]}"
    data = [type: type, q3: "\"\"\"", module: module]

    """
    defmodule <%= module %> do
      # This module was generated from an ontology. DO NOT EDIT!
      # Run `mix help ontology.gen` for details.

      @moduledoc <%= q3 %>
      <%= type[:typedoc] %>
      <%= q3 %>

      @namespace :<%= type[:ns_atom] %>
      @type_name "<%= type[:name] %>"
      @extended_by [
        <%= type[:extended_by] %>
      ]
      @is_or_extends [
        <%= type[:is_or_extends] %>
      ]
      @disjoint_with [
        <%= type[:disjoint_with] %>
      ]
      @known_properties [
        <%= type[:properties] %>
      ]

      @enforce_keys [:alias]
      defstruct [
        :alias,
        properties: %{},
        unknown: %{}
      ]

      @type t() :: %__MODULE__{
              alias: String.t(),
              properties: map(),
              unknown: map()
            }

      def namespace, do: @namespace
      def type_name, do: @type_name
      def extended_by, do: @extended_by
      def is_or_extends?(type_name), do: Enum.member?(@is_or_extends, type_name)
      def disjoint_with?(type_name), do: Enum.member?(@disjoint_with, type_name)
      def known_property?(prop_name), do: Enum.member?(@known_properties, prop_name)

      def new(opts \\\\ []) do
        alias = Keyword.get(opts, :alias, "")
        properties = Keyword.get(opts, :properties, %{})
        context = Keyword.get(opts, :context, :simple)

        %__MODULE__{alias: alias, properties: properties}
        |> Fedi.Streams.Utils.as_type_set_json_ld_type(@type_name)
        |> Fedi.Streams.Utils.set_context(context)
      end

      def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
        Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
      end

      def serialize(%__MODULE__{} = object) do
        Fedi.Streams.BaseType.serialize(object)
      end
    end
    """
    |> render_file(data, dir, filename)
  end

  def render_functional_prop(prop) do
    dir = Path.join(prop[:ns_atom], "property")
    filename = Macro.underscore(prop[:name]) <> @file_ext
    mod_name = Fedi.Streams.Utils.capitalize(prop[:name])
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
      @range <%= prop[:range] %>
      @domain [
        <%= prop[:domain] %>
      ]
      @prop_name <%= prop[:names] %>

      @enforce_keys [:alias]
      defstruct [
        :alias<%= prop[:defstruct] %>,
        unknown: %{}
      ]

      @type t() :: %__MODULE__{
              alias: String.t()<%= prop[:typet] %>,
              unknown: map()
            }

      def prop_name, do: @prop_name
      def range, do: @range
      def domain, do: @domain
      def functional?, do: true
      def iterator_module, do: nil
      def parent_module, do: nil

      def new(alias_ \\\\ "") do
        %__MODULE__{alias: alias_}
      end

      def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
        Fedi.Streams.BaseProperty.deserialize(
          @namespace,
          __MODULE__,
          @range,
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

  def render_non_functional_prop(prop) do
    dir = Path.join(prop[:ns_atom], "property")
    filename = Macro.underscore(prop[:name]) <> @file_ext
    mod_name = Fedi.Streams.Utils.capitalize(prop[:name])
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
      @range <%= prop[:range] %>
      @domain [
        <%= prop[:domain] %>
      ]
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

      def prop_name, do: @prop_name
      def range, do: @range
      def domain, do: @domain
      def functional?, do: false
      def iterator_module, do: <%= module %>Iterator
      def parent_module, do: nil

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

  def render_iterator_prop(prop) do
    dir = Path.join(prop[:ns_atom], "property")
    filename = Macro.underscore(prop[:name]) <> "_iterator" <> @file_ext
    parent_mod_name = Fedi.Streams.Utils.capitalize(prop[:name])
    module = "Fedi.#{prop[:namespace]}.Property.#{parent_mod_name}Iterator"
    parent_module = "Fedi.#{prop[:namespace]}.Property.#{parent_mod_name}"
    data = [prop: prop, q3: "\"\"\"", module: module, parent_module: parent_module]

    """
    defmodule <%= module %> do
      # This module was generated from an ontology. DO NOT EDIT!
      # Run `mix help ontology.gen` for details.

      @moduledoc <%= q3 %>
      Iterator for the <%= prop[:namespace] %> "<%= prop[:name] %>" property.
      <%= q3 %>

      @namespace :<%= prop[:ns_atom] %>
      @range <%= prop[:range] %>
      @domain [
        <%= prop[:domain] %>
      ]
      @prop_name <%= prop[:names] %>

      @enforce_keys [:alias]
      defstruct [
        :alias<%= prop[:defstruct] %>,
        unknown: %{}
      ]

      @type t() :: %__MODULE__{
              alias: String.t()<%= prop[:typet] %>,
              unknown: map()
            }

      def prop_name, do: @prop_name
      def range, do: @range
      def domain, do: @domain
      def functional?, do: false
      def iterator_module, do: nil
      def parent_module, do: <%= parent_module %>

      def new(alias_ \\\\ "") do
        %__MODULE__{alias: alias_}
      end

      def deserialize(prop_name, mapped_property?, i, alias_map) when is_map(alias_map) do
        Fedi.Streams.PropertyIterator.deserialize(
          @namespace,
          __MODULE__,
          @range,
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

  def render_file(template, data, dir, filename) do
    contents = EEx.eval_string(template, data)

    dir = Path.join(@output_dir, dir)
    File.mkdir_p(dir)

    Path.join(dir, filename)
    |> File.write(contents)
  end
end
