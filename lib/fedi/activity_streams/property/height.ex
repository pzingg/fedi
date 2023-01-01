defmodule Fedi.ActivityStreams.Property.Height do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  On a Link, specifies a hint as to the rendering height in device-independent
  pixels of the linked resource.
  """

  @namespace :activity_streams
  @member_types [:non_neg_integer]
  @prop_name "height"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :xsd_non_neg_integer_member,
    has_non_neg_integer_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_non_neg_integer_member?: boolean(),
          xsd_non_neg_integer_member: non_neg_integer() | nil,
          iri: URI.t() | nil
        }

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @member_types,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
