defmodule Fedi.ActivityStreams.Property.Published do
  @moduledoc false

  @prop_name "published"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_date_time_member,
    :has_date_time_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_date_time_member: DateTime.t(),
          has_date_time_member: boolean(),
          unknown: term(),
          iri: URI.t() | nil
        }
  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_date_time(
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
