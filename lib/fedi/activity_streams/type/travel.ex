defmodule Fedi.ActivityStreams.Type.Travel do
  @moduledoc """
  Indicates that the actor is traveling to target from origin. Travel is an
  IntransitiveActivity whose actor specifies the direct object. If the target
  or origin are not specified, either can be determined by context.

  Example 35 (https://www.w3.org/TR/activitystreams-vocabulary/#ex169-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "origin": {
        "name": "Work",
        "type": "Place"
      },
      "summary": "Sally went home from work",
      "target": {
        "name": "Home",
        "type": "Place"
      },
      "type": "Travel"
    }
  """

  defmodule Meta do
    def type_name, do: "Travel"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Activity", "IntransitiveActivity", "Object"]
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
