defmodule Fedi.ActivityStreams.Type.Delete do
  @moduledoc """
  Indicates that the actor has deleted the object. If specified, the origin
  indicates the context from which the object was deleted.

  Example 16 (https://www.w3.org/TR/activitystreams-vocabulary/#ex13-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http://example.org/notes/1",
      "origin": {
        "name": "Sally's Notes",
        "type": "Collection"
      },
      "summary": "Sally deleted a note",
      "type": "Delete"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Delete"
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
