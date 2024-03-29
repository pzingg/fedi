defmodule Fedi.ActivityStreams.Property.Deleted do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  On a Tombstone object, the deleted property is a timestamp for when the object
  was deleted.
  """

  @namespace :activity_streams
  @range [:date_time]
  @domain [
    {"Tombstone", Fedi.ActivityStreams.Type.Tombstone}
  ]
  @prop_name "deleted"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_date_time_member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_date_time_member: DateTime.t() | nil,
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
