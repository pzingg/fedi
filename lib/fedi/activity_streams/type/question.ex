defmodule Fedi.ActivityStreams.Type.Question do
  @moduledoc """
  Represents a question being asked. Question objects are an extension of
  IntransitiveActivity. That is, the Question object is an Activity, but the
  direct object is the question itself and therefore it would not contain an
  object property. Either of the anyOf and oneOf properties MAY be used to
  express possible answers, but a Question object MUST NOT have both
  properties.

  Example 40 (https://www.w3.org/TR/activitystreams-vocabulary/#ex55a-jsonld):
    {
      "name": "What is the answer?",
      "oneOf": [
        {
          "name": "Option A",
          "type": "Note"
        },
        {
          "name": "Option B",
          "type": "Note"
        }
      ],
      "type": "Question"
    }

  Example 41 (https://www.w3.org/TR/activitystreams-vocabulary/#ex55b-jsonld):
    {
      "closed": "2016-05-10T00:00:00Z",
      "name": "What is the answer?",
      "type": "Question"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Question"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Activity", "IntransitiveActivity", "Object"]
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
