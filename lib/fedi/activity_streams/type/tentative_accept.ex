defmodule Fedi.ActivityStreams.Type.TentativeAccept do
  @moduledoc """
  A specialization of Accept indicating that the acceptance is tentative.

  Example 11 (https://www.w3.org/TR/activitystreams-vocabulary/#ex8-jsonld):
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
      "summary": "Sally tentatively accepted an invitation to a party",
      "type": "TentativeAccept"
    }
  """

  defmodule Meta do
    def type_name, do: "TentativeAccept"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Accept", "Activity", "Object"]
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
