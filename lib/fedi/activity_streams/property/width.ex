defmodule Fedi.ActivityStreams.Property.Width do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  On a Link, specifies a hint as to the rendering width in device-independent
  pixels of the linked resource.
  """

  @namespace :activity_streams
  @range [:non_neg_integer]
  @domain [
    {"Hashtag", Fedi.ActivityStreams.Type.Hashtag},
    {"Image", Fedi.ActivityStreams.Type.Image},
    {"Link", Fedi.ActivityStreams.Type.Link},
    {"Mention", Fedi.ActivityStreams.Type.Mention}
  ]
  @prop_name "width"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_non_neg_integer_member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_non_neg_integer_member: non_neg_integer() | nil,
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
