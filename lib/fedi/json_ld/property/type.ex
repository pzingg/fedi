defmodule Fedi.JSONLD.Property.Type do
  @moduledoc """
  Identifies the schema type(s) of the JSON-LD entity.
  """

  @namespace :json_ld
  @range [:any_uri, :string]
  @domain :any_object
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

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: false
  def iterator_module, do: Fedi.JSONLD.Property.TypeIterator
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  @doc """
  Creates a new 'type' property with the value `type`.
  """
  def new_type(type, alias_ \\ "") when is_binary(type) do
    new(alias_) |> set(type)
  end

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

  def set(%__MODULE__{alias: alias_} = prop, type) when is_binary(type) do
    new_iter =
      case Fedi.Streams.Literal.AnyURI.deserialize(type) do
        {:ok, v} ->
          %Fedi.JSONLD.Property.TypeIterator{alias: alias_, xsd_any_uri_member: v}

        _ ->
          %Fedi.JSONLD.Property.TypeIterator{alias: alias_, xsd_string_member: type}
      end

    %__MODULE__{prop | values: [new_iter]}
  end

  def clear(%__MODULE__{} = prop) do
    %__MODULE__{prop | values: []}
  end
end
