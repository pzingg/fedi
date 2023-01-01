defmodule Fedi.JSON.LD.Property.Id do
  @moduledoc """
  Provides the globally unique identifier for JSON-LD entities.
  """

  @namespace :json_ld
  @member_types [:any_uri]
  @prop_name "id"

  defstruct [
    :xsd_any_uri_member,
    :unknown,
    :alias
  ]

  @type t() :: %__MODULE__{
          xsd_any_uri_member: URI.t() | nil,
          unknown: term(),
          alias: String.t()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @member_types,
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
  # is_xsd_any_uri afterwards will return false.
  def clear(%__MODULE__{} = prop) do
    %__MODULE__{prop | unknown: nil, xsd_any_uri_member: nil}
  end
end
