defmodule Fedi.ActivityStreams.Property.NameIterator do
  @moduledoc """
  ActivityStreamsActorPropertyIterator is an iterator for a property. It is
  permitted to be one of multiple value types. At most, one type of value can
  be present, or none at all. Setting a value will clear the other types of
  values so that only one of the 'Is' methods will return true. It is
  possible to clear all values, so that this property is empty.
  """

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_string_member,
    :has_string_member,
    :rdf_lang_string_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_string_member: String.t() | nil,
          has_string_member: boolean(),
          rdf_lang_string_member: map() | nil,
          unknown: term(),
          iri: URI.t() | nil
        }

  def deserialize(i, prop_name, mapped_property?, alias_map) when is_map(alias_map) do
    Fedi.Streams.PropertyIterator.deserialize(
      :activity_streams,
      __MODULE__,
      i,
      prop_name,
      mapped_property?,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end

  def name(%{alias: alias_, rdf_lang_string_member: lang_string}) do
    Fedi.Streams.BaseProperty.name("name", alias_, is_map(lang_string))
  end
end
