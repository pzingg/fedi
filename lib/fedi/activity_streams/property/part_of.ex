defmodule Fedi.ActivityStreams.Property.PartOf do
  @moduledoc false

  @prop_name "partOf"
  @member_types [
    Fedi.ActivityStreams.Type.Collection,
    Fedi.ActivityStreams.Type.CollectionPage,
    Fedi.ActivityStreams.Type.Link,
    Fedi.ActivityStreams.Type.Mention,
    Fedi.ActivityStreams.Type.OrderedCollection,
    Fedi.ActivityStreams.Type.OrderedCollectionPage
  ]

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
    Fedi.Streams.BaseProperty.deserialize(
      :activity_streams,
      __MODULE__,
      @prop_name,
      m,
      alias_map,
      @member_types
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
