defmodule Fedi.ActivityStreams.Type.Event do
  @moduledoc """
  Represents any kind of event.

  Example 55 (https://www.w3.org/TR/activitystreams-vocabulary/#ex56-jsonld):
    {
      "endTime": "2015-01-01T06:00:00-08:00",
      "name": "Going-Away Party for Jim",
      "startTime": "2014-12-31T23:00:00-08:00",
      "type": "Event"
    }
  """

  defmodule Meta do
    def type_name, do: "Event"
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

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end
end
