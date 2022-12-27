defmodule Fedi.ActivityStreams.Type.View do
  @moduledoc """
  Indicates that the actor has viewed the object.

  Example 31 (https://www.w3.org/TR/activitystreams-vocabulary/#ex161-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "What You Should Know About Activity Streams",
        "type": "Article"
      },
      "summary": "Sally read an article",
      "type": "View"
    }
  """

  defmodule Meta do
    def type_name, do: "View"
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
