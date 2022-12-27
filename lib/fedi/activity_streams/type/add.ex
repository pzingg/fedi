defmodule Fedi.ActivityStreams.Type.Add do
  @moduledoc """
  Indicates that the actor has added the object to the target. If the target
  property is not explicitly specified, the target would need to be
  determined implicitly by context. The origin can be used to identify the
  context from which the object originated.

  Example 12 (https://www.w3.org/TR/activitystreams-vocabulary/#ex9-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http://example.org/abc",
      "summary": "Sally added an object",
      "type": "Add"
    }

  Example 13 (https://www.w3.org/TR/activitystreams-vocabulary/#ex10-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "A picture of my cat",
        "type": "Image",
        "url": "http://example.org/img/cat.png"
      },
      "origin": {
        "name": "Camera Roll",
        "type": "Collection"
      },
      "summary": "Sally added a picture of her cat to her cat picture
  collection",
      "target": {
        "name": "My Cat Pictures",
        "type": "Collection"
      },
      "type": "Add"
    }
  """

  defmodule Meta do
    def type_name, do: "Add"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Activity, Object"]
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

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end
end
