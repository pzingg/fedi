defmodule Fedi.Streams.PropertyIterator do
  @moduledoc false

  require Logger

  def deserialize(namespace, module, i, alias_map, types \\ nil) do
    Fedi.Streams.get_alias(alias_map, namespace)
    |> Fedi.Streams.BaseProperty.deserialize_with_alias(module, i, alias_map, types)
  end

  def deserialize_name(namespace, module, i, alias_map) when is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case Fedi.Streams.BaseProperty.maybe_iri(i) do
      {:ok, uri} ->
        {:ok, struct(module, alias: alias_, iri: uri)}

      _ ->
        case Fedi.Streams.Literal.LangString.deserialize(i) do
          {:ok, v} ->
            {:ok, struct(module, alias: alias_, rdf_lang_string_member: v)}

          _ ->
            case Fedi.Streams.Literal.String.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 struct(module,
                   alias: alias_,
                   xml_schema_string_member: v,
                   has_string_member: true
                 )}

              {:error, reason} ->
                {:error, reason}
            end
        end
    end
    |> case do
      {:ok, this} -> {:ok, this}
      _error -> {:ok, struct(module, alias: alias_, unknown: i)}
    end
  end

  def iterator_module(module) do
    Module.split(module)
    |> List.update_at(-1, fn name -> name <> "Iterator" end)
    |> Module.concat()
  end

  def clear(%{__struct__: _module, mapped_properties: _, properties: _} = prop) do
    struct(prop, mapped_properties: [], properties: [])
  end

  def clear(%{__struct__: _module, properties: _} = prop) do
    struct(prop, properties: [])
  end

  # append_iri appends an IRI value to the back of a list of the property "type"
  def append_iri(%{__struct__: module, alias: alias_, properties: properties} = prop, %URI{} = v) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        properties ++
          [
            struct(prop_mod, alias: alias_, xml_schema_any_uri_member: v)
          ]
    )
  end

  # append_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def append_xml_schema_any_uri(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        %URI{} = v
      ) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        properties ++
          [
            struct(prop_mod, alias: alias_, xml_schema_any_uri_member: v)
          ]
    )
  end

  # append_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def append_xml_schema_string(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        v
      )
      when is_binary(v) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        properties ++
          [
            struct(prop_mod,
              alias: alias_,
              has_string_member: true,
              xml_schema_string_member: v
            )
          ]
    )
  end

  # prepend_iri appends an IRI value to the back of a list of the property "type"
  def prepend_iri(%{__struct__: module, alias: alias_, properties: properties} = prop, %URI{} = v) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties: [
        struct(prop_mod, alias: alias_, xml_schema_any_uri_member: v) | properties
      ]
    )
  end

  # prepend_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def prepend_xml_schema_any_uri(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        %URI{} = v
      ) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties: [
        struct(prop_mod, alias: alias_, xml_schema_any_uri_member: v)
        | properties
      ]
    )
  end

  # prepend_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def prepend_xml_schema_string(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        v
      )
      when is_binary(v) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties: [
        struct(prop_mod,
          alias: alias_,
          has_string_member: true,
          xml_schema_string_member: v
        )
        | properties
      ]
    )
  end

  # insert_iri inserts an IRI value at the specified index for a property "type".
  # Existing elements at that index and higher are shifted back once.
  # Invalidates all iterators.
  def insert_iri(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        i,
        %URI{} = v
      )
      when is_integer(i) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        List.insert_at(
          properties,
          i,
          struct(prop_mod,
            alias: alias_,
            xml_schema_any_uri_member: v
          )
        )
    )
  end

  # insert_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def insert_xml_schema_any_uri(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        i,
        %URI{} = v
      )
      when is_integer(i) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        List.insert_at(
          properties,
          i,
          struct(prop_mod,
            alias: alias_,
            xml_schema_any_uri_member: v
          )
        )
    )
  end

  # insert_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def insert_xml_schema_string(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        i,
        v
      )
      when is_integer(i) and is_binary(v) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        List.insert_at(
          properties,
          i,
          struct(prop_mod,
            alias: alias_,
            has_string_member: true,
            xml_schema_string_member: v
          )
        )
    )
  end

  # set_iri sets an IRI value to be at the specified index for the property "type".
  # Panics if the index is out of bounds.
  def set_iri(%{__struct__: module, alias: alias_, properties: properties} = prop, i, %URI{} = v)
      when is_integer(i) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        List.update_at(properties, i, fn _ ->
          struct(prop_mod,
            alias: alias_,
            xml_schema_any_uri_member: v
          )
        end)
    )
  end

  # set_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def set_xml_schema_any_uri(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        i,
        %URI{} = v
      )
      when is_integer(i) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        List.update_at(properties, i, fn _ ->
          struct(prop_mod,
            alias: alias_,
            xml_schema_any_uri_member: v
          )
        end)
    )
  end

  # set_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def set_xml_schema_string(
        %{__struct__: module, alias: alias_, properties: properties} = prop,
        i,
        v
      )
      when is_integer(i) and is_binary(v) do
    prop_mod = iterator_module(module)

    struct(
      prop,
      properties:
        List.update_at(properties, i, fn _ ->
          struct(prop_mod,
            alias: alias_,
            has_string_member: true,
            xml_schema_string_member: v
          )
        end)
    )
  end

  # Remove deletes an element at the specified index from a list of the property
  # "type", regardless of its type. Panics if the index is out of bounds.
  #  Invalidates all iterators.
  def remove(%{mapped_properties: mapped_properties, properties: properties} = prop, i)
      when is_integer(i) do
    try do
      struct(prop, properties: List.delete_at(properties, i))
    rescue
      _ ->
        struct(
          prop,
          mapped_properties: List.delete_at(mapped_properties, i - Enum.count(properties))
        )
    end
  end

  def remove(%{properties: properties} = prop, i)
      when is_integer(i) do
    struct(prop, properties: List.delete_at(properties, i))
  end

  # wwap swaps the location of values at two indices for the "type" property.
  def swap(%{properties: properties} = prop, i, j)
      when is_integer(i) and is_integer(j) do
    if i == j do
      prop
    else
      p1 = at(prop, i)
      p2 = at(prop, j)

      properties =
        properties
        |> List.update_at(i, fn _ -> p2 end)
        |> List.update_at(j, fn _ -> p1 end)

      struct(prop, properties: properties)
    end
  end

  # at returns the property value for the specified index. Panics if the index is
  # out of bounds.
  def at(%{mapped_properties: mapped_properties, properties: properties}, i) when is_integer(i) do
    try do
      Enum.at(properties, i)
    rescue
      _ ->
        Enum.at(mapped_properties, i - Enum.count(properties))
    end
  end

  def at(%{properties: properties}, i) when is_integer(i) do
    Enum.at(properties, i)
  end

  # empty returns true if there are no elements.
  def empty(%{mapped_properties: [], properties: []}), do: true
  def empty(%{mapped_properties: _, properties: _}), do: false
  def empty(%{properties: []}), do: true
  def empty(_prop), do: false

  # len returns the number of elements.
  def len(%{mapped_properties: mapped_properties, properties: properties}) do
    Enum.count(mapped_properties) + Enum.count(properties)
  end

  def len(%{properties: properties}), do: Enum.count(properties)

  def all_properties(%{mapped_properties: mapped_properties, properties: properties}) do
    properties ++ mapped_properties
  end

  def all_properties(%{properties: properties}), do: properties
  def all_properties(_), do: []

  # json_ld_context returns the JSONLD URIs required in the context string
  # for this property and the specific values that are set. The value
  # in the map is the alias used to import the property's value or
  # values.
  def json_ld_context(prop) do
    prop
    |> all_properties()
    |> Enum.reduce(Map.new(), fn v, acc ->
      case v do
        %{__struct__: module} ->
          child = apply(module, :json_ld_context, [v])

          # Since the Fedi.Streams.Literal maps in this function are determined at
          # code-generation time, this loop should not overwrite an existing key with a
          # new value.
          Map.merge(acc, child)

        _ ->
          acc
      end
    end)
  end

  # KindIndex computes an arbitrary value for indexing this kind of value. This is
  # a leaky API method specifically needed only for alternate implementations
  # for go-fed. Applications should not use this method. Panics if the index is
  # out of bounds.
  def kind_index(prop, idx) when is_integer(idx) do
    case at(prop, idx) do
      %{__struct__: module} = child ->
        apply(module, :kind_index, [child])

      _ ->
        -1
    end
  end

  # Less computes whether another property is less than this one. Mixing types
  # results in a consistent but arbitrary ordering
  def less(prop, i, j) when is_integer(i) and is_integer(j) do
    idx1 = kind_index(prop, i)
    idx2 = kind_index(prop, j)

    cond do
      idx1 < idx2 ->
        true

      idx1 == idx2 ->
        case idx1 do
          0 ->
            lhs = at(prop, i) |> Fedi.Streams.BaseProperty.get_xml_schema_any_uri()
            rhs = at(prop, j) |> Fedi.Streams.BaseProperty.get_xml_schema_any_uri()
            Fedi.Streams.Literal.AnyURI.less(lhs, rhs)

          1 ->
            lhs = at(prop, i) |> Fedi.Streams.BaseProperty.get_xml_schema_string()
            rhs = at(prop, j) |> Fedi.Streams.BaseProperty.get_xml_schema_string()
            Fedi.Streams.Literal.String.less(lhs, rhs)

          -2 ->
            lhs = at(prop, i) |> Fedi.Streams.BaseProperty.get_iri()
            rhs = at(prop, j) |> Fedi.Streams.BaseProperty.get_iri()
            to_string(lhs) < to_string(rhs)

          _ ->
            false
        end

      true ->
        false
    end
  end

  # LessThan compares two instances of this property with an arbitrary but stable
  # comparison. Applications should not use this because it is only meant to
  # help alternative implementations to go-fed to be able to normalize
  # nonfunctional properties.
  def less_than(prop, o) do
    l1 = len(prop)
    l2 = len(o)
    last = min(l1, l2) - 1

    Enum.reduce_while(0..last, l1 < l2, fn i, acc ->
      p1 = at(prop, i)
      p2 = at(o, i)

      cond do
        Fedi.Streams.BaseProperty.less_than(p1, p2) -> [:halt, true]
        Fedi.Streams.BaseProperty.less_than(p2, p1) -> [:halt, false]
        true -> [:cont, acc]
      end
    end)
  end
end
