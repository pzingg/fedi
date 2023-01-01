defmodule Fedi.ActivityStreams.Property.Duration do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  When the object describes a time-bound resource, such as an audio or video, a
  meeting, etc, the duration property indicates the object's approximate
  duration. The value MUST be expressed as an xsd:duration as defined by
  [xmlschema11-2], section 3.3.6 (e.g. a period of 5 seconds is represented as
  "PT5S").
  """

  @namespace :activity_streams
  @member_types [:duration]
  @prop_name "duration"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :xsd_duration_member,
    has_duration_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_duration_member?: boolean(),
          xsd_duration_member: Timex.Duration.t() | nil,
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
