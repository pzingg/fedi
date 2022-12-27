defmodule Fedi.ActivityStreams.Type.Read do
  @moduledoc """
  Indicates that the actor has read the object.

  Example 33 (https://www.w3.org/TR/activitystreams-vocabulary/#ex164-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http://example.org/posts/1",
      "summary": "Sally read a blog post",
      "type": "Read"
    }
  """

  defmodule Meta do
    def type_name, do: "Read"
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

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end
end
