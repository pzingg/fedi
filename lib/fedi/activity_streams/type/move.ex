defmodule Fedi.ActivityStreams.Type.Move do
  @moduledoc """
  Indicates that the actor has moved object from origin to target. If the origin
  or target are not specified, either can be determined by context.

  Example 34 (https://www.w3.org/TR/activitystreams-vocabulary/#ex168-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http://example.org/posts/1",
      "origin": {
        "name": "List A",
        "type": "Collection"
      },
      "summary": "Sally moved a post from List A to List B",
      "target": {
        "name": "List B",
        "type": "Collection"
      },
      "type": "Move"
    }
  """

  defmodule Meta do
    def type_name, do: "Move"
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
