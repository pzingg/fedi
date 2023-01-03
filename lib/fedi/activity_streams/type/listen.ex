defmodule Fedi.ActivityStreams.Type.Listen do
  @moduledoc """
  Indicates that the actor has listened to the object.

  Example 32 (https://www.w3.org/TR/activitystreams-vocabulary/#ex163-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http://example.org/music.mp3",
      "summary": "Sally listened to a piece of music",
      "type": "Listen"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Listen"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Activity", "Object"]
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
