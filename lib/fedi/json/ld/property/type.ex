defmodule Fedi.JSON.LD.Property.Type do
  @moduledoc """
  Identifies the schema type(s) of the JSON-LD entity.
  """

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
    %__MODULE__{prop | properties: []}
  end
end
