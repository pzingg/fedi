defmodule Fedi.ActivityStreams.Type.Image do
  @moduledoc """
  An image document of any kind

  Example 51 (https://www.w3.org/TR/activitystreams-vocabulary/#ex50-jsonld):
    {
      "name": "Cat Jumping on Wagon",
      "type": "Image",
      "url": [
        {
          "mediaType": "image/jpeg",
          "type": "Link",
          "url": "http://example.org/image.jpeg"
        },
        {
          "mediaType": "image/png",
          "type": "Link",
          "url": "http://example.org/image.png"
        }
      ]
    }
  """

  defmodule Meta do
    def type_name, do: "Image"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Document", "Object"]
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
