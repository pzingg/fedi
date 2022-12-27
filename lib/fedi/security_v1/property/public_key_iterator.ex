defmodule SecurityV1.Property.PublicKeyIterator do
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
    Fedi.Streams.PropertyIterator.deserialize(:security_v1, __MODULE__, i, alias_map)
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
