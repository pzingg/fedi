defmodule Fedi.ActivityStreams.Property.AttributedToIterator do
  @moduledoc """
  ActivityStreamsActorPropertyIterator is an iterator for a property. It is
  permitted to be one of multiple value types. At most, one type of value can
  be present, or none at all. Setting a value will clear the other types of
  values so that only one of the 'Is' methods will return true. It is
  possible to clear all values, so that this property is empty.
  """

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
    Fedi.Streams.PropertyIterator.deserialize(:activity_streams, __MODULE__, i, alias_map)
  end
end
