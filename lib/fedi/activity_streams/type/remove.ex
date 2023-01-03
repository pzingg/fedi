defmodule Fedi.ActivityStreams.Type.Remove do
  @moduledoc """
  Indicates that the actor is removing the object. If specified, the origin
  indicates the context from which the object is being removed.

  Example 27 (https:www.w3.org/TR/activitystreams-vocabulary/#ex28-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http:example.org/notes/1",
      "summary": "Sally removed a note from her notes folder",
      "target": {
        "name": "Notes Folder",
        "type": "Collection"
      },
      "type": "Remove"
    }

  Example 28 (https:www.w3.org/TR/activitystreams-vocabulary/#ex29-jsonld):
    {
      "actor": {
        "name": "The Moderator",
        "type": "http:example.org/Role"
      },
      "object": {
        "name": "Sally",
        "type": "Person"
      },
      "origin": {
        "name": "A Simple Group",
        "type": "Group"
      },
      "summary": "The moderator removed Sally from a group",
      "type": "Remove"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Remove"
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
