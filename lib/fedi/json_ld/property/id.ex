defmodule Fedi.JSONLD.Property.Id do
  @moduledoc """
  Provides the globally unique identifier for JSON-LD entities.
  """

  @namespace :json_ld
  @range [:any_uri]
  @domain :any_object
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

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  @doc """
  Creates a new 'id' property with the given `id`.
  """
  def new_id(%URI{} = id, alias_ \\ "") do
    new(alias_) |> set(id)
  end

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @range,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end

  def set(%__MODULE__{} = prop, %URI{} = id) do
    %__MODULE__{prop | xsd_any_uri_member: id}
  end

  def clear(%__MODULE__{} = prop) do
    %__MODULE__{prop | unknown: %{}, xsd_any_uri_member: nil}
  end
end
