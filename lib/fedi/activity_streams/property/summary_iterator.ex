defmodule Fedi.ActivityStreams.Property.SummaryIterator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Iterator for the ActivityStreams "summary" property.
  """

  @namespace :activity_streams
  @member_types [:lang_string, :string]

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :rdf_lang_string_member,
    :xsd_string_member,
    has_string_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_string_member?: boolean(),
          xsd_string_member: String.t() | nil,
          rdf_lang_string_member: map() | nil,
          iri: URI.t() | nil
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
