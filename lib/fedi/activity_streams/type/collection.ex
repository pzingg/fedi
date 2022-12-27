defmodule Fedi.ActivityStreams.Type.Collection do
  @moduledoc """
  A Collection is a subtype of Object that represents ordered or unordered sets
  of Object or Link instances. Refer to the Activity Streams 2.0 Core
  specification for a complete description of the Collection type.

  Example 5 (https://www.w3.org/TR/activitystreams-vocabulary/#ex5-jsonld):
    {
      "items": [
        {
          "name": "A Simple Note",
          "type": "Note"
        },
        {
          "name": "Another Simple Note",
          "type": "Note"
        }
      ],
      "summary": "Sally's notes",
      "totalItems": 2,
      "type": "Collection"
    }
  """

  defmodule Meta do
    def type_name, do: "Collection"
    def disjoint_with, do: ["Link", "Mention"]

    def extended_by,
      do: [
        "CollectionPage",
        "OrderedCollection",
        "OrderedCollectionPage",
        "OrderedCollectionPage"
      ]

    def extends, do: ["Object"]
  end

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    properties: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          properties: map(),
          unknown: term()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end

  def serialize(%__MODULE__{} = object) do
    Fedi.Streams.BaseType.serialize(object)
  end
end
