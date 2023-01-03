defmodule Fedi.ActivityStreams.Type.Link do
  @moduledoc """
  A Link is an indirect, qualified reference to a resource identified by a URL.
  The fundamental model for links is established by [RFC5988]. Many of the
  properties defined by the Activity Vocabulary allow values that are either
  instances of Object or Link. When a Link is used, it establishes a
  qualified relation connecting the subject (the containing object) to the
  resource identified by the href. Properties of the Link are properties of
  the reference as opposed to properties of the resource.

  Example 2 (https://www.w3.org/TR/activitystreams-vocabulary/#ex2-jsonld):
    {
      "hreflang": "en",
      "mediaType": "text/html",
      "name": "An example link",
      "type": "Link",
      "url": "http://example.org/abc"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Link"

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

    def extended_by, do: ["Mention"]
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
