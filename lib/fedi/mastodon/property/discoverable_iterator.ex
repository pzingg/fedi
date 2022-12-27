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

  def deserialize(i, alias_map) when is_map(alias_map) do
    Fedi.Streams.PropertyIterator.deserialize(:mastodon, __MODULE__, i, alias_map)
  end
end
