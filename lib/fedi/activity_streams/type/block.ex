defmodule Fedi.ActivityStreams.Type.Block do
  @moduledoc """
  Indicates that the actor is blocking the object. Blocking is a stronger form of
  Ignore. The typical use is to support social systems that allow one user to
  block activities or content of other users. The target and origin typically
  have no defined meaning.

  Example 37 (https://www.w3.org/TR/activitystreams-vocabulary/#ex173-jsonld):
    {
      "actor": "http://sally.example.org",
      "object": "http://joe.example.org",
      "summary": "Sally blocked Joe",
      "type": "Block"
    }
  """

  defmodule Meta do
    def type_name, do: "Block"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Activity", "Ignore", "Object"]
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
