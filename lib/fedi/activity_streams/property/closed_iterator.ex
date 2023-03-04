defmodule Fedi.ActivityStreams.Property.ClosedIterator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Iterator for the ActivityStreams "closed" property.
  """

  @namespace :activity_streams
  @range [:boolean, :date_time, :iri, :object]
  @domain [
    {"Question", Fedi.ActivityStreams.Type.Question}
  ]
  @prop_name "closed"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_date_time_member,
    :xsd_boolean_member,
    :member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_date_time_member: DateTime.t() | nil,
          xsd_boolean_member: boolean() | nil,
          member: term(),
          iri: URI.t() | nil,
          unknown: map()
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: false
  def iterator_module, do: nil
  def parent_module, do: Fedi.ActivityStreams.Property.Closed

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(prop_name, mapped_property?, i, context) when is_map(context) do
    Fedi.Streams.PropertyIterator.deserialize(
      @namespace,
      __MODULE__,
      @range,
      prop_name,
      mapped_property?,
      i,
      context
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
