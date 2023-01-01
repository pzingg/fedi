defmodule Fedi.ActivityStreams.Property.Hreflang do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Hints as to the language used by the target resource. Value MUST be a [BCP47]
  Language-Tag.
  """

  @namespace :activity_streams
  @member_types [:bcp47]
  @prop_name "hreflang"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :rfc_bcp47_member,
    has_bcp47_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_bcp47_member?: boolean(),
          rfc_bcp47_member: String.t() | nil,
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
