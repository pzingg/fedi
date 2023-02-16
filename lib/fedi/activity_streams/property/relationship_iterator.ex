defmodule Fedi.ActivityStreams.Property.RelationshipIterator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Iterator for the ActivityStreams "relationship" property.
  """

  @namespace :activity_streams
  @range [:iri, :object]
  @domain [
    {"Relationship", Fedi.ActivityStreams.Type.Relationship},
    {"TicketDependency", Fedi.ActivityStreams.Type.TicketDependency}
  ]
  @prop_name "relationship"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          member: term(),
          iri: URI.t() | nil,
          unknown: map()
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: false
  def iterator_module, do: nil
  def parent_module, do: Fedi.ActivityStreams.Property.Relationship

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
