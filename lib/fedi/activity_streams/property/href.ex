defmodule Fedi.ActivityStreams.Property.Href do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The target resource pointed to by a Link.
  """

  @namespace :activity_streams
  @range [:any_uri]
  @domain [
    {"Hashtag", Fedi.ActivityStreams.Type.Hashtag},
    {"Link", Fedi.ActivityStreams.Type.Link},
    {"Mention", Fedi.ActivityStreams.Type.Mention}
  ]
  @prop_name "href"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_any_uri_member,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_any_uri_member: URI.t() | nil,
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
