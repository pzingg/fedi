defmodule Fedi.ActivityStreams.Type.Activity do
  @moduledoc """
  An Activity is a subtype of Object that describes some form of action that may
  happen, is currently happening, or has already happened. The Activity type
  itself serves as an abstract base type for all types of activities. It is
  important to note that the Activity type itself does not carry any specific
  semantics about the kind of action being taken.

  Example 3 (https://www.w3.org/TR/activitystreams-vocabulary/#ex3-jsonld):
  {
    "actor": {
      "name": "Sally",
      "type": "Person"
    },
    "object": {
      "name": "A Note",
      "type": "Note"
    },
    "summary": "Sally did something to a note",
    "type": "Activity"
  }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Activity"
    def disjoint_with, do: ["Link", "Mention"]

    def extended_by,
      do: [
        "Accept",
        "Add",
        "Announce",
        "Arrive",
        "Block",
        "Create",
        "Delete",
        "Dislike",
        "Flag",
        "Follow",
        "Ignore",
        "IntransitiveActivity",
        "Invite",
        "Join",
        "Leave",
        "Like",
        "Listen",
        "Move",
        "Offer",
        "Question",
        "Read",
        "Reject",
        "Remove",
        "TentativeAccept",
        "TentativeReject",
        "Travel",
        "Undo",
        "Update",
        "View"
      ]

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
