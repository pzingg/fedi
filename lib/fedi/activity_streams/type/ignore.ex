defmodule Fedi.ActivityStreams.Type.Ignore do
  @moduledoc """
  Indicates that the actor is ignoring the object. The target and origin
  typically have no defined meaning.

  Example 18 (https://www.w3.org/TR/activitystreams-vocabulary/#ex16-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": "http://example.org/notes/1",
      "summary": "Sally ignored a note",
      "type": "Ignore"
    }
  """

  defmodule Meta do
    def type_name, do: "Ignore"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["Block"]
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

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end
end
