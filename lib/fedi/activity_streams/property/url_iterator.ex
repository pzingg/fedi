defmodule Fedi.ActivityStreams.Property.UrlIterator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Iterator for the ActivityStreams "url" property.
  """

  @namespace :activity_streams
  @member_types [:any_uri, :iri, :object]

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :xsd_any_uri_member,
    :member
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          member: term(),
          xsd_any_uri_member: URI.t() | nil
        }

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(prop_name, mapped_property?, i, alias_map) when is_map(alias_map) do
    Fedi.Streams.PropertyIterator.deserialize(
      @namespace,
      __MODULE__,
      @member_types,
      prop_name,
      mapped_property?,
      i,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
