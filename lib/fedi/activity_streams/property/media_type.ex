defmodule Fedi.ActivityStreams.Property.MediaType do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  When used on a Link, identifies the MIME media type of the referenced
  resource. When used on an Object, identifies the MIME media type of the value
  of the content property. If not specified, the content property is assumed to
  contain text/html content.
  """

  @namespace :activity_streams
  @member_types [:rfc2045]
  @prop_name "mediaType"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :rfc_rfc2045_member,
    has_rfc2045_member?: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          has_rfc2045_member?: boolean(),
          rfc_rfc2045_member: String.t() | nil,
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
