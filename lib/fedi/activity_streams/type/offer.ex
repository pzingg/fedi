defmodule Fedi.ActivityStreams.Type.Offer do
  @moduledoc """
  Indicates that the actor is offering the object. If specified, the target
  indicates the entity to which the object is being offered.

  Example 23 (https://www.w3.org/TR/activitystreams-vocabulary/#ex21-jsonld):
    {
      "actor": {
        "name": "Sally",
        "type": "Person"
      },
      "object": {
        "name": "50%!O(MISSING)ff!",
        "type": "http://www.types.example/ProductOffer"
      },
      "summary": "Sally offered 50%!o(MISSING)ff to Lewis",
      "target": {
        "name": "Lewis",
        "type": "Person"
      },
      "type": "Offer"
    }
  """

  defmodule Meta do
    def type_name, do: "Offer"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["Invite"]
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
