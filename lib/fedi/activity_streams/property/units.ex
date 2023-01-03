defmodule Fedi.ActivityStreams.Property.Units do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Specifies the measurement units for the radius and altitude properties on a
  Place object. If not specified, the default is assumed to be "m" for "meters".
  """

  @namespace :activity_streams
  @member_types [:any_uri, :string]
  @prop_name "units"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :xsd_any_uri_member,
    :xsd_string_member,
    has_string_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_string_member?: boolean(),
          xsd_string_member: String.t() | nil,
          xsd_any_uri_member: URI.t() | nil
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
