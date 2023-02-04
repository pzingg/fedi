defmodule Fedi.ActivityStreams.Property.Relationship do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  On a Relationship object, the relationship property identifies the kind of
  relationship that exists between subject and object.
  """

  @namespace :activity_streams
  @range [:iri, :object]
  @domain [
    {"Relationship", Fedi.ActivityStreams.Type.Relationship},
    {"TicketDependency", Fedi.ActivityStreams.Type.TicketDependency}
  ]
  @prop_name "relationship"

  @enforce_keys :alias
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
  def iterator_module, do: Fedi.ActivityStreams.Property.RelationshipIterator
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
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
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
