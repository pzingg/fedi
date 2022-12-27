defmodule Fedi.ActivityStreams.Type.CollectionPage do
  @moduledoc """
  Used to represent distinct subsets of items from a Collection. Refer to the
  Activity Streams 2.0 Core for a complete description of the CollectionPage
  object.

  Example 7 (https://www.w3.org/TR/activitystreams-vocabulary/#ex6b-jsonld):
    {
      "id": "http://example.org/foo?page=1",
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
      "partOf": "http://example.org/foo",
      "summary": "Page 1 of Sally's notes",
      "type": "CollectionPage"
    }
  """

  defmodule Meta do
    def type_name, do: "CollectionPage"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["OrderedCollectionPage"]
    def extends, do: ["Collection", "Object"]
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

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end
end
