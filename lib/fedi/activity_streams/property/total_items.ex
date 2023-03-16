defmodule Fedi.ActivityStreams.Property.TotalItems do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  A non-negative integer specifying the total number of objects contained by the
  logical view of the collection. This number might not reflect the actual
  number of items serialized within the Collection object instance.
  """

  @namespace :activity_streams
  @range [:non_neg_integer]
  @domain [
    {"Collection", Fedi.ActivityStreams.Type.Collection},
    {"CollectionPage", Fedi.ActivityStreams.Type.CollectionPage},
    {"OrderedCollection", Fedi.ActivityStreams.Type.OrderedCollection},
    {"OrderedCollectionPage", Fedi.ActivityStreams.Type.OrderedCollectionPage}
  ]
  @prop_name "totalItems"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_non_neg_integer_member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_non_neg_integer_member: non_neg_integer() | nil,
          iri: URI.t() | nil,
          unknown: map()
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: true
  def iterator_module, do: nil
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, context) when is_map(m) and is_map(context) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @range,
      @prop_name,
      m,
      context
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
