defmodule Fedi.JSON.LD.Property.Id do
  @moduledoc """
  Provides the globally unique identifier for JSON-LD entities.
  """

  @prop_name "id"

  defstruct [
    :xml_schema_any_uri_member,
    :unknown,
    :alias
  ]

  @type t() :: %__MODULE__{
          xml_schema_any_uri_member: URI.t() | nil,
          unknown: term(),
          alias: String.t()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_uri(
      :json_ld,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end

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
    %__MODULE__{prop | unknown: nil, xml_schema_any_uri_member: nil}
  end
end
