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
    {"Hashtag", Fedi.ActivityStreams.Type.Hashtag},
    {"Link", Fedi.ActivityStreams.Type.Link},
    {"Mention", Fedi.ActivityStreams.Type.Mention}
  ]
  @prop_name "hreflang"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :rfc_bcp47_member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          rfc_bcp47_member: String.t() | nil,
          iri: URI.t() | nil,
          unknown: map()
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

  def deserialize(m, context) when is_map(m) and is_map(context) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @range,
      @prop_name,
      m,
      context
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
