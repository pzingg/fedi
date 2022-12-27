defmodule Fedi.ActivityStreams.Type.Undo do
  @moduledoc """
  Indicates that the actor is undoing the object. In most cases, the object will
  be an Activity describing some previously performed action (for instance, a
  person may have previously "liked" an article but, for whatever reason,
  might choose to undo that like at some later point in time). The target and
  origin typically have no defined meaning.

  Example 29 (https://www.w3.org/TR/activitystreams-vocabulary/#ex32-jsonld):
    {
      "actor": "http://sally.example.org",
      "object": {
        "actor": "http://sally.example.org",
        "object": "http://example.org/posts/1",
        "target": "http://john.example.org",
        "type": "Offer"
      },
      "summary": "Sally retracted her offer to John",
      "type": "Undo"
    }
  """

  defmodule Meta do
    def type_name, do: "Undo"
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
