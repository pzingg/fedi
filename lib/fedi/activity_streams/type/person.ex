defmodule Fedi.ActivityStreams.Type.Person do
  @moduledoc """
  Represents an individual person.

  Example 45 (https://www.w3.org/TR/activitystreams-vocabulary/#ex39-jsonld):
    {
      "name": "Sally Smith",
      "type": "Person"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Person"
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
