defmodule Fedi.ActivityStreams.Property.Href do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The target resource pointed to by a Link.
  """

  @namespace :activity_streams
  @member_types [:any_uri]
  @prop_name "href"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :xsd_any_uri_member
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
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
