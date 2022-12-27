defmodule Fedi.ActivityStreams.Type.Profile do
  @moduledoc """
  A Profile is a content object that describes another Object, typically used to
  describe Actor Type objects. The describes property is used to reference
  the object being described by the profile.

  Example 59 (https://www.w3.org/TR/activitystreams-vocabulary/#ex184a-jsonld):
    {
      "describes": {
        "name": "Sally Smith",
        "type": "Person"
      },
      "summary": "Sally's Profile",
      "type": "Profile"
    }
  """

  defmodule Meta do
    def type_name, do: "Profile"
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
