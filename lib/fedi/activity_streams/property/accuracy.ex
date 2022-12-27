defmodule Fedi.ActivityStreams.Property.Accuracy do
  @moduledoc false

  @prop_name "accuracy"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_float_member,
    :has_float_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_float_member: float(),
          has_float_member: boolean(),
          unknown: term(),
          iri: URI.t() | nil
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_float(
      :activity_streams,
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
