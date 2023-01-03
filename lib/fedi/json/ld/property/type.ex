defmodule Fedi.JSON.LD.Property.Type do
  @moduledoc """
  Identifies the schema type(s) of the JSON-LD entity.
  """

  @namespace :json_ld
  @prop_name "type"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    values: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          values: list()
        }

  # deserialize creates a "type" property from an interface representation
  # that has been unmarshalled from a text or binary format.
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
    Fedi.Streams.BaseProperty.serialize_values(prop)
  end

  @doc """
  Creates a new type property.
  """
  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def new_type(type, alias_ \\ "") when is_binary(type) do
    new(alias_) |> set(type)
  end

  @doc """
  Returns the name of this property: "type".
  """
  def name(%__MODULE__{alias: alias_}) do
    Fedi.Streams.BaseProperty.name(@prop_name, alias_)
  end

  def set(%__MODULE__{alias: alias_} = prop, type) when is_binary(type) do
    %__MODULE__{
      prop
      | values: [
          %Fedi.JSON.LD.Property.TypeIterator{
            alias: alias_,
            has_string_member?: true,
            xsd_string_member: type
          }
        ]
    }
  end

  @doc """
  Ensures no value of this property is set. Calling
  `is_xsd_any_uri` afterwards will return false.
  """
  def clear(%__MODULE__{} = prop) do
    %__MODULE__{prop | values: []}
  end
end
