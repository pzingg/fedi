defmodule Fedi.ActivityStreams.Property.Following do
  @moduledoc false

  @prop_name "following"
  @member_types [
    Fedi.ActivityStreams.Type.Collection,
    Fedi.ActivityStreams.Type.CollectionPage,
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
end
