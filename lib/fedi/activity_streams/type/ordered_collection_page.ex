defmodule Fedi.ActivityStreams.Type.OrderedCollectionPage do
  @moduledoc """
  Used to represent ordered subsets of items from an OrderedCollection. Refer to
  the Activity Streams 2.0 Core for a complete description of the
  OrderedCollectionPage object.

  Example 8 (https://www.w3.org/TR/activitystreams-vocabulary/#ex6c-jsonld):
    {
      "id": "http://example.org/foo?page=1",
      "orderedItems": [
        {
          "name": "A Simple Note",
          "type": "Note"
        },
        {
          "name": "Another Simple Note",
          "type": "Note"
        }
      ],
      "partOf": "http://example.org/foo",
      "summary": "Page 1 of Sally's notes",
      "type": "OrderedCollectionPage"
    }
  """

  defmodule Meta do
    def type_name, do: "OrderedCollectionPage"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Collection", "CollectionPage", "Object", "OrderedCollection"]
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
