defmodule Fedi.Mastodon.Property.DiscoverableIterator do
  @moduledoc false

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :iri,
    :member
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          iri: URI.t() | nil,
          member: term()
        }

  def deserialize(i, prop_name, mapped_property?, alias_map) when is_map(alias_map) do
    Fedi.Streams.PropertyIterator.deserialize(
      :activity_streams,
      __MODULE__,
      i,
      prop_name,
      mapped_property?,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
