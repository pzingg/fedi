defmodule Fedi.ActivityStreams.Property.Subject do
  @moduledoc false

  @prop_name "subject"

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

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize(:activity_streams, __MODULE__, @prop_name, m, alias_map)
  end
end
