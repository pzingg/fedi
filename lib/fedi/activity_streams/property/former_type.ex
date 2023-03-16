defmodule Fedi.ActivityStreams.Property.FormerType do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  On a Tombstone object, the formerType property identifies the type of the
  object that was deleted.
  """

  @namespace :activity_streams
  @range [:iri, :object, :string]
  @domain [
    {"Tombstone", Fedi.ActivityStreams.Type.Tombstone}
  ]
  @prop_name "formerType"

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
  def iterator_module, do: Fedi.ActivityStreams.Property.FormerTypeIterator
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
