defmodule Fedi.ActivityStreams.Property.Width do
  @moduledoc false

  @prop_name "width"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_non_neg_integer_member,
    :has_non_neg_integer_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_non_neg_integer_member: non_neg_integer(),
          has_non_neg_integer_member: boolean(),
          unknown: term(),
          iri: URI.t() | nil
        }
  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_nni(
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
