defmodule Fedi.ActivityStreams.Property.Generator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Identifies the entity (e.g. an application) that generated the object.
  """

  @namespace :activity_streams
  @prop_name "generator"

  @enforce_keys :alias
  defstruct [
    :alias,
    values: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          values: list()
        }

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
