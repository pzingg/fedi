defmodule Fedi.ActivityStreams.Type.Group do
  @moduledoc """
  Represents a formal or informal collective of Actors.

  Example 43 (https://www.w3.org/TR/activitystreams-vocabulary/#ex37-jsonld):
    {
      "name": "Big Beards of Austin",
      "type": "Group"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Group"
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
