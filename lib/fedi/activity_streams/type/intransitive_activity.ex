defmodule Fedi.ActivityStreams.Type.IntransitiveActivity do
  @moduledoc """
  Instances of IntransitiveActivity are a subtype of Activity representing
  intransitive actions. The object property is therefore inappropriate for
  these activities.

  Example 4 (https://www.w3.org/TR/activitystreams-vocabulary/#ex182-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "summary": "Sally went to work",
      "target": {
        "name": "Work",
        "type": "Place"
      },
      "type": "Travel"
    }
  """

  defmodule Meta do
    def type_name, do: "IntransitiveActivity"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["Arrive", "Question", "Travel"]
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
