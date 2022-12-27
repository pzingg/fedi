defmodule Fedi.ActivityStreams.Type.Relationship do
  @moduledoc """
  Describes a relationship between two individuals. The subject and object
  properties are used to identify the connected individuals. See 5.2
  Representing Relationships Between Entities for additional information.

  Example 47 (https://www.w3.org/TR/activitystreams-vocabulary/#ex22-jsonld):
    {
      "object": {
        "name": "John",
        "type": "Person"
      },
      "relationship": "http://purl.org/vocab/relationship/acquaintanceOf",
      "subject": {
        "name": "Sally",
        "type": "Person"
      },
      "summary": "Sally is an acquaintance of John",
      "type": "Relationship"
    }
  """

  defmodule Meta do
    def type_name, do: "Relationship"
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
