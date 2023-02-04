defmodule Fedi.ActivityStreams.Property.FormerTypeIterator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Iterator for the ActivityStreams "formerType" property.
  """

  @namespace :activity_streams
  @range [:iri, :object, :string]
  @domain [
    {"Tombstone", Fedi.ActivityStreams.Type.Tombstone}
  ]
  @prop_name "formerType"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :xsd_string_member,
    :member,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          xsd_string_member: String.t() | nil,
          member: term(),
          iri: URI.t() | nil
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: false
  def iterator_module, do: nil
  def parent_module, do: Fedi.ActivityStreams.Property.FormerType

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(prop_name, mapped_property?, i, alias_map) when is_map(alias_map) do
    Fedi.Streams.PropertyIterator.deserialize(
      @namespace,
      __MODULE__,
      @range,
      prop_name,
      mapped_property?,
      i,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
