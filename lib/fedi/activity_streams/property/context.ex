defmodule Fedi.ActivityStreams.Property.Context do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Identifies the context within which the object exists or an activity was
  performed. The notion of "context" used is intentionally vague. The intended
  function is to serve as a means of grouping objects and activities that share
  a common originating context or purpose. An example could be all activities
  relating to a common project or event.
  """

  @namespace :activity_streams
  @prop_name "context"

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
