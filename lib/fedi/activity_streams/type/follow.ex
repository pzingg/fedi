defmodule Fedi.ActivityStreams.Type.Follow do
  @moduledoc """
  Indicates that the actor is "following" the object. Following is defined in the
  sense typically used within Social systems in which the actor is interested
  in any activity performed by or on the object. The target and origin
  typically have no defined meaning.

  Example 17 (https://www.w3.org/TR/activitystreams-vocabulary/#ex15-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "John",
        "type": "Person"
      },
      "summary": "Sally followed John",
      "type": "Follow"
    }
  """

  defmodule Meta do
    def type_name, do: "Follow"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
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
