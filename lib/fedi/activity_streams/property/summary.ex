defmodule Fedi.ActivityStreams.Property.Summary do
  @moduledoc false

  require Logger

  @prop_name ["summary", "summaryMap"]

  @enforce_keys :alias
  defstruct [
    :alias,
    mapped_values: [],
    values: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          mapped_values: list(),
          values: list()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_values(
      :activity_streams,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize_mapped_values(prop)
  end
end
