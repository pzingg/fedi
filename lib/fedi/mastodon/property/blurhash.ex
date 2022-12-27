defmodule Fedi.Mastodon.Property.Blurhash do
  @moduledoc false

  @prop_name "blurhash"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_string_member,
    :xml_schema_any_uri_member,
    :unknown,
    has_string_member: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_string_member: String.t() | nil,
          has_string_member: boolean(),
          xml_schema_any_uri_member: URI.t() | nil,
          unknown: term()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_string(
      :mastodon,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end

  # new creates a new type property.
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
    %__MODULE__{
      prop
      | xml_schema_string_member: nil,
        has_string_member: false,
        xml_schema_any_uri_member: nil,
        unknown: nil
    }
  end
end
