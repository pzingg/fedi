defmodule Fedi.ActivityStreams.Type.Place do
  @moduledoc """
  Represents a logical or physical location. See 5.3 Representing Places for
  additional information.

  Example 56 (https://www.w3.org/TR/activitystreams-vocabulary/#ex57-jsonld):
    {
      "name": "Work",
      "type": "Place"
    }

  Example 57 (https://www.w3.org/TR/activitystreams-vocabulary/#ex58-jsonld):
    {
      "latitude": 36.75,
      "longitude": 119.7667,
      "name": "Fresno Area",
      "radius": 15,
      "type": "Place",
      "units": "miles"
    }
  """

  defmodule Meta do
    def type_name, do: "Place"
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
