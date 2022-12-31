defmodule Fedi.JSON.LD.Property.TypeIterator do
  @moduledoc """
  TypeIterator represents a single value for the "type" property.

  TypeIterator is an iterator for a property. It is permitted to be
  one of multiple value types. At most, one type of value can be present, or
  none at all. Setting a value will clear the other types of values so that
  only one of the 'Is' methods will return true. It is possible to clear all
  values, so that this property is empty.
  """

  @prop_name "JSONLDType"

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

  # deserialize creates an iterator from an element that
  # has been unmarshalled from a text or binary format.

  def deserialize(i, prop_name, mapped_property?, alias_map) when is_map(alias_map) do
    alias_ = ""

    case Fedi.Streams.Literal.AnyURI.deserialize(i) do
      {:ok, v} ->
        {:ok, %__MODULE__{alias: alias_, xml_schema_any_uri_member: v}}

      _ ->
        case Fedi.Streams.Literal.String.deserialize(i) do
          {:ok, v} ->
            {:ok,
             %__MODULE__{alias: alias_, has_string_member: true, xml_schema_string_member: v}}

          _ ->
            {:ok, %__MODULE__{alias: alias_, unknown: i}}
        end
    end
  end

  # serialize converts this into an interface representation suitable for
  # marshalling into a text or binary format. Applications should not
  # need this function as most typical use cases serialize types
  # instead of individual properties. It is exposed for alternatives to
  # go-fed implementations to use.
  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end

  # new creates a new id property.
  def new() do
    %__MODULE__{alias: ""}
  end

  # name returns the name of this property: "id".
  def name(%__MODULE__{alias: alias_}) do
    Fedi.Streams.BaseProperty.name(@prop_name, alias_)
  end

  # clear ensures no value of this property is set. Calling
  # is_xml_schema_any_uri afterwards will return false.
  def clear(%__MODULE__{} = prop) do
    %__MODULE__{prop | unknown: nil, xml_schema_any_uri_member: nil, has_string_member: false}
  end
end
