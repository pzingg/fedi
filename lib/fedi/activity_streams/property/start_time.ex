defmodule Fedi.ActivityStreams.Property.StartTime do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The date and time describing the actual or expected starting time of the
  object. When used with an Activity object, for instance, the startTime
  property specifies the moment the activity began or is scheduled to begin.
  """

  @namespace :activity_streams
  @member_types [:date_time]
  @prop_name "startTime"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :xsd_date_time_member,
    has_date_time_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_date_time_member?: boolean(),
          xsd_date_time_member: DateTime.t() | nil,
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
