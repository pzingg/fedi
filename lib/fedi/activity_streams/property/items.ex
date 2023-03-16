defmodule Fedi.ActivityStreams.Property.Items do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Identifies the items contained in a collection. The items might be ordered or
  unordered.
  """

  @namespace :activity_streams
  @range [:iri, :object]
  @domain [
    {"Collection", Fedi.ActivityStreams.Type.Collection},
    {"CollectionPage", Fedi.ActivityStreams.Type.CollectionPage}
  ]
  @prop_name "items"

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
  def iterator_module, do: Fedi.ActivityStreams.Property.ItemsIterator
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, context) when is_map(m) and is_map(context) do
    Fedi.Streams.BaseProperty.deserialize_values(
      @namespace,
      __MODULE__,
      @prop_name,
      m,
      context
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
