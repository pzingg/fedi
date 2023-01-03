defmodule Fedi.ActivityStreams.Type.Accept do
  @moduledoc """
  Indicates that the actor accepts the object. The target property can be used in
  certain circumstances to indicate the context into which the object has
  been accepted.

  Example 9 (https://www.w3.org/TR/activitystreams-vocabulary/#ex7a-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "actor": "http://john.example.org",
        "object": {
          "name": "Going-Away Party for Jim",
          "type": "Event"
        },
        "type": "Invite"
      },
      "summary": "Sally accepted an invitation to a party",
      "type": "Accept"
    }

  Example 10 (https://www.w3.org/TR/activitystreams-vocabulary/#ex7b-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "Joe",
        "type": "Person"
      },
      "summary": "Sally accepted Joe into the club",
      "target": {
        "name": "The Club",
        "type": "Group"
      },
      "type": "Accept"
    }

  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Accept"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["TentativeAccept"]
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
