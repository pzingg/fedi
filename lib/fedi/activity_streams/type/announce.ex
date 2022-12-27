defmodule Fedi.ActivityStreams.Type.Announce do
  @moduledoc """
  Indicates that the actor is calling the target's attention the object. The
  origin typically has no defined meaning.

  Example 36 (https://www.w3.org/TR/activitystreams-vocabulary/#ex170-jsonld):
    {
      "actor": {
        "id": "http://sally.example.org",
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "actor": "http://sally.example.org",
        "location": {
          "name": "Work",
          "type": "Place"
        },
        "type": "Arrive"
      },
      "summary": "Sally announced that she had arrived at work",
      "type": "Announce"
    }
  """

  defmodule Meta do
    def type_name, do: "Announce"
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
