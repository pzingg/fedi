defmodule Fedi.ActivityStreams.Type.Service do
  @moduledoc """
  Represents a service of any kind.

  Example 46 (https://www.w3.org/TR/activitystreams-vocabulary/#ex42-jsonld):
    {
      "name": "Acme Web Service",
      "type": "Service"
    }
  """

  defmodule Meta do
    def type_name, do: "Service"
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
