defmodule Fedi.ActivityStreams.Type.Invite do
  @moduledoc """
  A specialization of Offer in which the actor is extending an invitation for the
  object to the target.

  Example 24 (https://www.w3.org/TR/activitystreams-vocabulary/#ex24-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "A Party",
        "type": "Event"
      },
      "summary": "Sally invited John and Lisa to a party",
      "target": [
        {
          "name": "John",
          "type": "Person"
        },
        {
          "name": "Lisa",
          "type": "Person"
        }
      ],
      "type": "Invite"
    }
  """

  defmodule Meta do
    def type_name, do: "Invite"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Activity", "Object", "Offer"]
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
