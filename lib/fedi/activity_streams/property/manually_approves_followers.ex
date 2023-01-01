defmodule Fedi.ActivityStreams.Property.ManuallyApprovesFollowers do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Indicates that the actor manually approves Follow activities and that an
  automatic Accept should not be expected.
  """

  @namespace :activity_streams
  @member_types [:boolean]
  @prop_name "manuallyApprovesFollowers"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :xsd_boolean_member,
    has_boolean_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_boolean_member?: boolean(),
          xsd_boolean_member: boolean() | nil,
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
