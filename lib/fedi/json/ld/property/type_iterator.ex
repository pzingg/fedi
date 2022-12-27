defmodule Fedi.JSON.LD.Property.TypeIterator do
  @moduledoc """
  TypeIterator represents a single value for the "type" property.

  TypeIterator is an iterator for a property. It is permitted to be
  one of multiple value types. At most, one type of value can be present, or
  none at all. Setting a value will clear the other types of values so that
  only one of the 'Is' methods will return true. It is possible to clear all
  values, so that this property is empty.
  """

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_any_uri_member,
    :xml_schema_string_member,
    :unknown,
    has_string_member: false
  ]

  @type t() :: %__MODULE__{
          xml_schema_any_uri_member: URI.t() | nil,
          xml_schema_string_member: String.t() | nil,
          unknown: term(),
          alias: String.t(),
          has_string_member: boolean()
        }

  # new creates a new id property.
  def new() do
    %__MODULE__{alias: ""}
  end

  # name returns the name of this property: "id".
  def name(%__MODULE__{alias: alias}) do
    if String.length(alias) > 0 do
      alias <> ":JSONLDType"
    else
      "JSONLDType"
    end
  end

  # serialize converts this into an interface representation suitable for
  # marshalling into a text or binary format. Applications should not
  # need this function as most typical use cases serialize types
  # instead of individual properties. It is exposed for alternatives to
  # go-fed implementations to use.
  def serialize(%__MODULE__{} = prop) do
    cond do
      is_xml_schema_any_uri(prop) ->
        get_xml_schema_any_uri(prop) |> Fedi.Streams.Literal.AnyURI.serialize()

      is_xml_schema_string(prop) ->
        get_xml_schema_string(prop) |> Fedi.Streams.Literal.String.serialize()

      true ->
        {:ok, prop.unknown}
    end
  end

  # deserialize creates an iterator from an element that
  # has been unmarshalled from a text or binary format.
  def deserialize(i, alias_map) when is_map(alias_map) do
    alias = ""

    case Fedi.Streams.Literal.AnyURI.deserialize(i) do
      {:ok, v} ->
        {:ok, %__MODULE__{alias: alias, xml_schema_any_uri_member: v}}

      _ ->
        case Fedi.Streams.Literal.String.deserialize(i) do
          {:ok, v} ->
            {:ok, %__MODULE__{alias: alias, has_string_member: true, xml_schema_string_member: v}}

          _ ->
            {:ok, %__MODULE__{alias: alias, unknown: i}}
        end
    end
  end

  # clear ensures no value of this property is set. Calling
  # is_xml_schema_any_uri afterwards will return false.
  def clear(%__MODULE__{} = prop) do
    %__MODULE__{prop | unknown: nil, xml_schema_any_uri_member: nil, has_string_member: false}
  end

  # get_iri returns the IRI of this property. When is_iri returns false,
  # get_iri will return any arbitrary value.
  def get_iri(%__MODULE__{} = prop) do
    prop.xml_schema_any_uri_member
  end

  # get_xml_schema_any_uri returns the value of this property. When IsXMLSchemaAnyURI
  # returns false, get_xml_schema_any_uri will return an arbitrary value.
  def get_xml_schema_any_uri(%__MODULE__{} = prop) do
    prop.xml_schema_any_uri_member
  end

  # get_xml_schema_string returns the value of this property. When is_xml_schema_string
  # returns false, get_xml_schema_string will return an arbitrary value.
  def get_xml_schema_string(%__MODULE__{} = prop) do
    prop.xml_schema_string_member
  end

  # has_any returns true if any of the different values is set.
  def has_any(%__MODULE__{} = prop) do
    is_xml_schema_any_uri(prop) || is_xml_schema_string(prop)
  end

  # is_iri returns true if this property is an IRI.
  def is_iri(%__MODULE__{} = prop) do
    !is_nil(prop.xml_schema_any_uri_member)
  end

  # is_xml_schema_any_uri returns true if this property is set and not an IRI.
  def is_xml_schema_any_uri(%__MODULE__{} = prop) do
    !is_nil(prop.xml_schema_any_uri_member)
  end

  # is_xml_schema_string returns true if this property has a type of "string". When
  # true, use the get_xml_schema_string and set_xml_schema_string methods to access
  # and set this property.
  def is_xml_schema_string(%__MODULE__{} = prop) do
    prop.has_string_member
  end

  # json_ld_context returns the JSONLD URIs required in the context string
  # for this property and the specific values that are set. The value
  # in the map is the alias used to import the property's value or
  # values.
  def json_ld_context(%__MODULE__{} = _prop) do
    %{}
  end

  # kind_index computes an arbitrary value for indexing this kind of value.
  # This is a leaky API detail only for folks looking to replace the
  # go-fed implementation. Applications should not use this method.
  def kind_index(%__MODULE__{} = prop) do
    cond do
      is_xml_schema_any_uri(prop) -> 0
      is_xml_schema_string(prop) -> 1
      is_iri(prop) -> -2
      true -> -1
    end
  end

  # less_than compares two instances of this property with an arbitrary but
  # stable comparison. Applications should not use this because it is
  # only meant to help alternative implementations to go-fed to be able
  # to normalize nonfunctional properties.
  def less_than(%__MODULE__{} = prop, %__MODULE__{} = o) do
    idx1 = kind_index(prop)
    idx2 = kind_index(o)

    cond do
      idx1 < idx2 ->
        true

      idx1 > idx2 ->
        false

      is_xml_schema_any_uri(prop) ->
        Fedi.Streams.Literal.AnyURI.less(get_xml_schema_any_uri(prop), get_xml_schema_any_uri(o))

      is_xml_schema_string(prop) ->
        Fedi.Streams.Literal.String.less(get_xml_schema_string(prop), get_xml_schema_string(o))

      true ->
        false
    end
  end

  # set_iri sets the value of this property. Calling is_iri afterwards will
  # return true.
  def set_iri(%__MODULE__{} = prop, %URI{} = v) do
    prop
    |> clear()
    |> set_xml_schema_any_uri(v)
  end

  # SetXMLSchemaAnyURI sets the value of this property. Calling IsXMLSchemaAnyURI
  # afterwards returns true.
  def set_xml_schema_any_uri(%__MODULE__{} = prop, %URI{} = v) do
    prop = clear(prop)
    %__MODULE__{prop | xml_schema_any_uri_member: v}
  end

  # SetXMLSchemaAnyURI sets the value of this property. Calling IsXMLSchemaAnyURI
  # afterwards returns true.
  def set_xml_schema_string(%__MODULE__{} = prop, v) when is_binary(v) do
    prop = clear(prop)
    %__MODULE__{prop | xml_schema_string_member: v, has_string_member: true}
  end
end
