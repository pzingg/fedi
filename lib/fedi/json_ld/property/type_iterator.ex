defmodule Fedi.JSONLD.Property.TypeIterator do
  @moduledoc """
  TypeIterator represents a single value for the "type" property.

  TypeIterator is an iterator for a property. It is visible_to to be
  one of multiple value types. At most, one type of value can be present, or
  none at all. Setting a value will clear the other types of values so that
  only one of the 'is' methods will return true. It is possible to clear all
  values, so that this property is empty.
  """

  @namespace :json_ld
  @range [:any_uri, :string]
  @domain :any_object
  @prop_name "type"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :xsd_any_uri_member,
    :xsd_string_member
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          xsd_any_uri_member: URI.t() | nil,
          xsd_string_member: String.t() | nil
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: false
  def iterator_module, do: nil
  def parent_module, do: Fedi.JSONLD.Property.Type

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(_prop_name, _mapped_property?, i, alias_map) when is_map(alias_map) do
    case Fedi.Streams.Literal.AnyURI.deserialize(i) do
      {:ok, v} ->
        {:ok, %__MODULE__{alias: "", xsd_any_uri_member: v}}

      _ ->
        case Fedi.Streams.Literal.String.deserialize(i) do
          {:ok, v} ->
            {:ok, %__MODULE__{alias: "", xsd_string_member: v}}

          _ ->
            {:ok, %__MODULE__{alias: "", unknown: i}}
        end
    end
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
