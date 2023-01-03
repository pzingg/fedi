defmodule Fedi.ActivityStreams.Type.Reject do
  @moduledoc """
  Indicates that the actor is rejecting the object. The target and origin
  typically have no defined meaning.

  Example 25 (https://www.w3.org/TR/activitystreams-vocabulary/#ex26-jsonld):
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
      "summary": "Sally rejected an invitation to a party",
      "type": "Reject"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Reject"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["TentativeReject"]
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
