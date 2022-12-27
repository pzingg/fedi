defmodule Fedi.ActivityStreams.Type.Article do
  @moduledoc """
  Represents any kind of multi-paragraph written work.

  Example 48 (https://www.w3.org/TR/activitystreams-vocabulary/#ex43-jsonld):
    {
      "attributedTo": "http://sally.example.org",
      "content": "\u003cdiv\u003e... you will never believe
  ...\u003c/div\u003e",
      "name": "What a Crazy Day I Had",
      "type": "Article"
    }
  """

  defmodule Meta do
    def type_name, do: "Article"
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
