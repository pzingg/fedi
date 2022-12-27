defmodule Fedi.ActivityStreams.Type.OrderedCollection do
  @moduledoc """
  A subtype of Collection in which members of the logical collection are assumed
  to always be strictly ordered.

  Example 6 (https://www.w3.org/TR/activitystreams-vocabulary/#ex6-jsonld):
    {
      "orderedItems": [
        {
          "name": "A Simple Note",
          "type": "Note"
        },
        {
          "name": "Another Simple Note",
          "type": "Note"
        }
      ],
      "summary": "Sally's notes",
      "totalItems": 2,
      "type": "OrderedCollection"
    }
  """

  defmodule Meta do
    def type_name, do: "OrderedCollection"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["OrderedCollectionPage"]
    def extends, do: ["Collection", "Object"]
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
