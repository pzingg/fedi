defmodule Fedi.ActivityStreams.Type.Arrive do
  @moduledoc """
  An IntransitiveActivity that indicates that the actor has arrived at the
  location. The origin can be used to identify the context from which the
  actor originated. The target typically has no defined meaning.

  Example 14 (https://www.w3.org/TR/activitystreams-vocabulary/#ex11-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "location": {
        "name": "Work",
        "type": "Place"
      },
      "origin": {
        "name": "Home",
        "type": "Place"
      },
      "summary": "Sally arrived at work",
      "type": "Arrive"
    }
  """

  defmodule Meta do
    def type_name, do: "Arrive"
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
