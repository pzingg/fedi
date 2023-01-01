defmodule Fedi.ActivityStreams.Property.Content do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The content or textual representation of the Object encoded as a JSON string.
  By default, the value of content is HTML. The mediaType property can be used
  in the object to indicate a different content type. The content MAY be
  expressed using multiple language-tagged values.
  """

  @namespace :activity_streams
  @prop_name ["content", "contentMap"]

  @enforce_keys :alias
  defstruct [
    :alias,
    values: [],
    mapped_values: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          values: list(),
          mapped_values: list()
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
