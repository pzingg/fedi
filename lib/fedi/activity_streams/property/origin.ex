defmodule Fedi.ActivityStreams.Property.Origin do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Describes an indirect object of the activity from which the activity is
  directed. The precise meaning of the origin is the object of the English
  preposition "from". For instance, in the activity "John moved an item to List
  B from List A", the origin of the activity is "List A".
  """

  @namespace :activity_streams
  @prop_name "origin"

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
