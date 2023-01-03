defmodule Fedi.ActivityStreams.Type.Update do
  @moduledoc """
  Indicates that the actor has updated the object. Note, however, that this
  vocabulary does not define a mechanism for describing the actual set of
  modifications made to object. The target and origin typically have no
  defined meaning.

  Example 30 (https://www.w3.org/TR/activitystreams-vocabulary/#ex33-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http://example.org/notes/1",
      "summary": "Sally updated her note",
      "type": "Update"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Update"
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
