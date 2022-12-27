defmodule Fedi.ActivityStreams.Type.Object do
  @moduledoc """
  Describes an object of any kind. The Object type serves as the base type for
  most of the other kinds of objects defined in the Activity Vocabulary,
  including other Core types such as Activity, IntransitiveActivity,
  Collection and OrderedCollection.

  Example 1 (https://www.w3.org/TR/activitystreams-vocabulary/#ex1-jsonld):
    {
      "id": "http://www.test.example/object/1",
      "name": "A Simple, non-specific object",
      "type": "Object"
    }
  """

  defmodule Meta do
    def type_name, do: "Object"
    def disjoint_with, do: ["Link", "Mention"]

    def extended_by,
      do: [
        "Accept",
        "Activity",
        "Add",
        "Announce",
        "Application",
        "Arrive",
        "Article",
        "Audio",
        "Block",
        "Collection",
        "CollectionPage",
        "Create",
        "Delete",
        "Dislike",
        "Document",
        "Event",
        "Flag",
        "Follow",
        "Group",
        "Ignore",
        "Image",
        "IntransitiveActivity",
        "Invite",
        "Join",
        "Leave",
        "Like",
        "Listen",
        "Move",
        "Note",
        "Offer",
        "OrderedCollection",
        "OrderedCollectionPage",
        "OrderedCollectionPage",
        "Organization",
        "Page",
        "Person",
        "Place",
        "Profile",
        "Question",
        "Read",
        "Reject",
        "Relationship",
        "Remove",
        "Service",
        "TentativeAccept",
        "TentativeReject",
        "Tombstone",
        "Travel",
        "Undo",
        "Update",
        "Video",
        "View"
      ]

    def extends, do: []
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
