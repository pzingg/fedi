defmodule Fedi.ActivityStreams.Property.Href do
  @moduledoc false

  @prop_name "href"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_any_uri_member,
    :unknown
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_any_uri_member: URI.t(),
          unknown: term()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_uri(
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
