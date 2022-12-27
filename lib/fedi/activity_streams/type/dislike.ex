defmodule Fedi.ActivityStreams.Type.Dislike do
  @moduledoc """
  Indicates that the actor dislikes the object.

  Example 39 (https://www.w3.org/TR/activitystreams-vocabulary/#ex175-jsonld):
    {
      "actor": "http://sally.example.org",
      "object": "http://example.org/posts/1",
      "summary": "Sally disliked a post",
      "type": "Dislike"
    }
  """

  defmodule Meta do
    def type_name, do: "Dislike"
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
