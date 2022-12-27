defmodule Fedi.ActivityStreams.Type.Audio do
  @moduledoc """
  Represents an audio document of any kind.

  Example 50 (https://www.w3.org/TR/activitystreams-vocabulary/#ex49-jsonld):
    {
      "name": "Interview With A Famous Technologist",
      "type": "Audio",
      "url": {
        "mediaType": "audio/mp3",
        "type": "owl:Class",
        "url": "http://example.org/podcast.mp3"
      }
    }
  """

  defmodule Meta do
    def type_name, do: "Audio"
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
