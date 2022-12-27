defmodule Fedi.ActivityStreams.Type.Flag do
  @moduledoc """
  Indicates that the actor is "flagging" the object. Flagging is defined in the
  sense common to many social platforms as reporting content as being
  inappropriate for any number of reasons.

  Example 38 (https://www.w3.org/TR/activitystreams-vocabulary/#ex174-jsonld):
    {
      "actor": "http://sally.example.org",
      "object": {
        "content": "An inappropriate note",
        "type": "Note"
      },
      "summary": "Sally flagged an inappropriate note",
      "type": "Flag"
  """

  defmodule Meta do
    def type_name, do: "Flag"
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

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end
end
