defmodule Fedi.ActivityStreams.Property.Rel do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  A link relation associated with a Link. The value MUST conform to both the
  [HTML5] and [RFC5988] "link relation" definitions. In the [HTML5], any string
  not containing the "space" U+0020, "tab" (U+0009), "LF" (U+000A), "FF"
  (U+000C), "CR" (U+000D) or "," (U+002C) characters can be used as a valid link
  relation.
  """

  @namespace :activity_streams
  @prop_name "rel"

  @enforce_keys :alias
  defstruct [
    :alias,
    values: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          values: list()
        }

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_values(
      @namespace,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
