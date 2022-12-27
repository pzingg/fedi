defmodule Fedi.ActivityStreams.Type.Leave do
  @moduledoc """
  Indicates that the actor has left the object. The target and origin typically
  have no meaning.

  Example 20 (https://www.w3.org/TR/activitystreams-vocabulary/#ex18-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "Work",
        "type": "Place"
      },
      "summary": "Sally left work",
      "type": "Leave"
    }

  Example 21 (https://www.w3.org/TR/activitystreams-vocabulary/#ex19-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "A Simple Group",
        "type": "Group"
      },
      "summary": "Sally left a group",
      "type": "Leave"
    }
  """

  defmodule Meta do
    def type_name, do: "Leave"
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
