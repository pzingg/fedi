defmodule Fedi.ActivityStreams.Type.Mention do
  @moduledoc """
  A specialized Link that represents an @mention.

  Example 58 (https://www.w3.org/TR/activitystreams-vocabulary/#ex181-jsonld):
    {
      "name": "Joe",
      "summary": "Mention of Joe by Carrie in her note",
      "type": "Mention",
      "url": "http://example.org/joe"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Mention"

    def disjoint_with,
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
        "Object",
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

    def extended_by, do: []
    def extends, do: ["Link"]
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
