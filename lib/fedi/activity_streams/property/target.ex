defmodule Fedi.ActivityStreams.Property.Target do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Describes the indirect object, or target, of the activity. The precise meaning
  of the target is largely dependent on the type of action being described but
  will often be the object of the English preposition "to". For instance, in the
  activity "John added a movie to his wishlist", the target of the activity is
  John's wishlist. An activity can have more than one target.
  """

  @namespace :activity_streams
  @prop_name "target"

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
