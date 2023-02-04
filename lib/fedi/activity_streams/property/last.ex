defmodule Fedi.ActivityStreams.Property.Last do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  In a paged Collection, indicates the furthest proceeding page of the
  collection.
  """

  @namespace :activity_streams
  @range [:iri, :object]
  @domain [
    {"Collection", Fedi.ActivityStreams.Type.Collection},
    {"CollectionPage", Fedi.ActivityStreams.Type.CollectionPage},
    {"OrderedCollection", Fedi.ActivityStreams.Type.OrderedCollection},
    {"OrderedCollectionPage", Fedi.ActivityStreams.Type.OrderedCollectionPage}
  ]
  @prop_name "last"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :member,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          member: term(),
          iri: URI.t() | nil
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
end
