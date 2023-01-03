defmodule Fedi.ActivityStreams.Type.Tombstone do
  @moduledoc """
  A Tombstone represents a content object that has been deleted. It can be used
  in Collections to signify that there used to be an object at this position,
  but it has been deleted.

  Example 60 (https://www.w3.org/TR/activitystreams-vocabulary/#ex184b-jsonld):
    {
      "name": "Vacation photos 2016",
      "orderedItems": [
        {
          "id": "http://image.example/1",
          "type": "Image"
        },
        {
          "deleted": "2016-03-17T00:00:00Z",
          "formerType": "/Image",
          "id": "http://image.example/2",
          "type": "Tombstone"
        },
        {
          "id": "http://image.example/3",
          "type": "Image"
        }
      ],
      "totalItems": 3,
      "type": "OrderedCollection"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Tombstone"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
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
