defmodule Fedi.JSON.LD.Property.Type do
  @moduledoc """
  Identifies the schema type(s) of the JSON-LD entity.
  """

  alias Fedi.JSON.LD.Property.TypeIterator

  @prop_name "type"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    properties: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          properties: list()
        }

  # new creates a new type property.
  def new() do
    %__MODULE__{alias: ""}
  end

  # deserialize creates a "type" property from an interface representation
  # that has been unmarshalled from a text or binary format.
  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_properties(
      :json_ld,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize_properties(prop)
  end

  # name returns the name of this property: "type".
  def name(%__MODULE__{alias: alias_}) do
    Fedi.Streams.BaseProperty.name(@prop_name, alias_)
  end

  # append_iri appends an IRI value to the back of a list of the property "type"
  def append_iri(%__MODULE__{} = prop, %URI{} = v) do
    %__MODULE__{
      prop
      | properties:
          prop.properties ++
            [
              %TypeIterator{alias: prop.alias, xml_schema_any_uri_member: v}
            ]
    }
  end

  # append_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def append_xml_schema_any_uri(%__MODULE__{} = prop, %URI{} = v) do
    %__MODULE__{
      prop
      | properties:
          prop.properties ++
            [
              %TypeIterator{alias: prop.alias, xml_schema_any_uri_member: v}
            ]
    }
  end

  # append_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def append_xml_schema_string(%__MODULE__{} = prop, v) when is_binary(v) do
    %__MODULE__{
      prop
      | properties:
          prop.properties ++
            [
              %TypeIterator{
                alias: prop.alias,
                has_string_member: true,
                xml_schema_string_member: v
              }
            ]
    }
  end

  # prepend_iri appends an IRI value to the back of a list of the property "type"
  def prepend_iri(%__MODULE__{} = prop, %URI{} = v) do
    %__MODULE__{
      prop
      | properties: [
          %TypeIterator{alias: prop.alias, xml_schema_any_uri_member: v} | prop.properties
        ]
    }
  end

  # prepend_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def prepend_xml_schema_any_uri(%__MODULE__{} = prop, %URI{} = v) do
    %__MODULE__{
      prop
      | properties: [
          %TypeIterator{alias: prop.alias, xml_schema_any_uri_member: v}
          | prop.properties
        ]
    }
  end

  # prepend_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def prepend_xml_schema_string(%__MODULE__{} = prop, v) when is_binary(v) do
    %__MODULE__{
      prop
      | properties: [
          %TypeIterator{
            alias: prop.alias,
            has_string_member: true,
            xml_schema_string_member: v
          }
          | prop.properties
        ]
    }
  end

  # insert_iri inserts an IRI value at the specified index for a property "type".
  # Existing elements at that index and higher are shifted back once.
  # Invalidates all iterators.
  def insert_iri(%__MODULE__{} = prop, i, %URI{} = v) when is_integer(i) do
    %__MODULE__{
      prop
      | properties:
          List.insert_at(prop.properties, i, %TypeIterator{
            alias: prop.alias,
            xml_schema_any_uri_member: v
          })
    }
  end

  # insert_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def insert_xml_schema_any_uri(%__MODULE__{} = prop, i, %URI{} = v) when is_integer(i) do
    %__MODULE__{
      prop
      | properties:
          List.insert_at(prop.properties, i, %TypeIterator{
            alias: prop.alias,
            xml_schema_any_uri_member: v
          })
    }
  end

  # insert_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def insert_xml_schema_string(%__MODULE__{} = prop, i, v) when is_integer(i) and is_binary(v) do
    %__MODULE__{
      prop
      | properties:
          List.insert_at(prop.properties, i, %TypeIterator{
            alias: prop.alias,
            has_string_member: true,
            xml_schema_string_member: v
          })
    }
  end

  # set_iri sets an IRI value to be at the specified index for the property "type".
  # Panics if the index is out of bounds.
  def set_iri(%__MODULE__{} = prop, i, %URI{} = v) when is_integer(i) do
    %__MODULE__{
      prop
      | properties:
          List.update_at(prop.properties, i, fn _ ->
            %TypeIterator{
              alias: prop.alias,
              xml_schema_any_uri_member: v
            }
          end)
    }
  end

  # set_xml_schema_any_uri appends a anyURI value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def set_xml_schema_any_uri(%__MODULE__{} = prop, i, %URI{} = v) when is_integer(i) do
    %__MODULE__{
      prop
      | properties:
          List.update_at(prop.properties, i, fn _ ->
            %TypeIterator{
              alias: prop.alias,
              xml_schema_any_uri_member: v
            }
          end)
    }
  end

  # set_xml_schema_string appends a string value to the back of a list of the
  # property "type". Invalidates iterators that are traversing using Prev.
  def set_xml_schema_string(%__MODULE__{} = prop, i, v) when is_integer(i) and is_binary(v) do
    %__MODULE__{
      prop
      | properties:
          List.update_at(prop.properties, i, fn _ ->
            %TypeIterator{
              alias: prop.alias,
              has_string_member: true,
              xml_schema_string_member: v
            }
          end)
    }
  end

  # Remove deletes an element at the specified index from a list of the property
  # "type", regardless of its type. Panics if the index is out of bounds.
  #  Invalidates all iterators.
  def remove(%__MODULE__{} = prop, i) when is_integer(i) do
    %__MODULE__{
      prop
      | properties: List.delete_at(prop.properties, i)
    }
  end

  # wwap swaps the location of values at two indices for the "type" property.
  def swap(%__MODULE__{} = prop, i, j) when is_integer(i) and is_integer(j) do
    if i == j do
      prop
    else
      p1 = at(prop, i)
      p2 = at(prop, j)

      properties =
        prop.properties
        |> List.update_at(i, fn _ -> p2 end)
        |> List.update_at(j, fn _ -> p1 end)

      %__MODULE__{prop | properties: properties}
    end
  end

  # at returns the property value for the specified index. Panics if the index is
  # out of bounds.
  def at(%__MODULE__{} = prop, i) when is_integer(i) do
    Enum.at(prop.properties, i)
  end

  # begin returns the first iterator, or nil if empty. Can be used with the
  # iterator's Next method and this property's End method to iterate from front
  # to back through all values.
  def begin(%__MODULE__{} = prop) do
    if empty(prop) do
      nil
    else
      List.first(prop.properties)
    end
  end

  # empty returns true if there are no elements.
  def empty(%__MODULE__{} = prop) do
    prop.properties == []
  end

  # len returns the number of elements.
  def len(%__MODULE__{} = prop) do
    Enum.count(prop.properties)
  end

  # json_ld_context returns the JSONLD URIs required in the context string
  # for this property and the specific values that are set. The value
  # in the map is the alias used to import the property's value or
  # values.
  def json_ld_context(%__MODULE__{} = prop) do
    Enum.reduce(prop.properties, Map.new(), fn v, m ->
      child = TypeIterator.json_ld_context(v)

      # Since the Fedi.Streams.Literal maps in this function are determined at
      # code-generation time, this loop should not overwrite an existing key with a
      # new value.
      Map.merge(m, child)
    end)
  end

  # KindIndex computes an arbitrary value for indexing this kind of value. This is
  # a leaky API method specifically needed only for alternate implementations
  # for go-fed. Applications should not use this method. Panics if the index is
  # out of bounds.
  def kind_index(%__MODULE__{} = prop, idx) when is_integer(idx) do
    Enum.at(prop.properties, idx) |> TypeIterator.kind_index()
  end

  # Less computes whether another property is less than this one. Mixing types
  # results in a consistent but arbitrary ordering
  def less(%__MODULE__{} = prop, i, j) when is_integer(i) and is_integer(j) do
    idx1 = kind_index(prop, i)
    idx2 = kind_index(prop, j)

    cond do
      idx1 < idx2 ->
        true

      idx1 == idx2 ->
        case idx1 do
          0 ->
            lhs = at(prop, i) |> TypeIterator.get_xml_schema_any_uri()
            rhs = at(prop, 2) |> TypeIterator.get_xml_schema_any_uri()
            Fedi.Streams.Literal.AnyURI.less(lhs, rhs)

          1 ->
            lhs = at(prop, i) |> TypeIterator.get_xml_schema_string()
            rhs = at(prop, 2) |> TypeIterator.get_xml_schema_string()
            Fedi.Streams.Literal.String.less(lhs, rhs)

          -2 ->
            lhs = at(prop, i) |> TypeIterator.get_iri()
            rhs = at(prop, 2) |> TypeIterator.get_iri()
            to_string(lhs) < to_string(rhs)
        end

      true ->
        false
    end
  end

  # LessThan compares two instances of this property with an arbitrary but stable
  # comparison. Applications should not use this because it is only meant to
  # help alternative implementations to go-fed to be able to normalize
  # nonfunctional properties.
  def less_than(%__MODULE__{} = prop, %__MODULE__{} = o) do
    l1 = len(prop)
    l2 = len(o)
    last = min(l1, l2) - 1

    Enum.reduce_while(0..last, l1 < l2, fn i, acc ->
      p1 = at(prop, i)
      p2 = at(o, i)

      cond do
        TypeIterator.less_than(p1, p2) -> [:halt, true]
        TypeIterator.less_than(p2, p1) -> [:halt, false]
        true -> [:cont, acc]
      end
    end)
  end
end
