defmodule Fedi.ActivityStreams.Property.Hreflang do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Hints as to the language used by the target resource. Value MUST be a [BCP47]
  Language-Tag.
  """

  @namespace :activity_streams
  @range [:bcp47]
  @domain [
    {"Link", Fedi.ActivityStreams.Type.Link},
    {"Mention", Fedi.ActivityStreams.Type.Mention}
  ]
  @prop_name "hreflang"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :rfc_bcp47_member,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          rfc_bcp47_member: String.t() | nil,
          iri: URI.t() | nil
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: true
  def iterator_module, do: nil
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @range,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
