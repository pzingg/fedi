defmodule Fedi.ActivityStreams.Property.Accuracy do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Indicates the accuracy of position coordinates on a Place objects. Expressed
  in properties of percentage. e.g. "94.0" means "94.0% accurate".
  """

  @namespace :activity_streams
  @range [:float]
  @domain [
    {"Place", Fedi.ActivityStreams.Type.Place}
  ]
  @prop_name "accuracy"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :xsd_float_member,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          xsd_float_member: float() | nil,
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
