defmodule Fedi.ActivityStreams.Type.Object do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Describes an object of any kind. The Object type serves as the base type for
  most of the other kinds of objects defined in the Activity Vocabulary,
  including other Core types such as Activity, IntransitiveActivity, Collection
  and OrderedCollection.
  """

  @namespace :activity_streams
  @type_name "Object"
  @extended_by [
    "Accept",
    "Activity",
    "Add",
    "Announce",
    "Application",
    "Article",
    "Audio",
    "Branch",
    "Collection",
    "CollectionPage",
    "Commit",
    "Create",
    "Delete",
    "Dislike",
    "Document",
    "Emoji",
    "Event",
    "Flag",
    "Follow",
    "Group",
    "IdentityProof",
    "Ignore",
    "Image",
    "IntransitiveActivity",
    "Join",
    "Leave",
    "Like",
    "Listen",
    "Move",
    "Note",
    "Offer",
    "OrderedCollection",
    "Organization",
    "Page",
    "Person",
    "Place",
    "Profile",
    "Push",
    "Read",
    "Reject",
    "Relationship",
    "Remove",
    "Repository",
    "Service",
    "Ticket",
    "TicketDependency",
    "Tombstone",
    "Undo",
    "Update",
    "Video",
    "View"
  ]
  @is_or_extends [
    "Object"
  ]
  @disjoint_with [
    "Link",
    "Mention"
  ]
  @known_properties [
    "altitude",
    "attachment",
    "attributedTo",
    "audience",
    "bcc",
    "bto",
    "cc",
    "content",
    "contentMap",
    "context",
    "duration",
    "endTime",
    "generator",
    "icon",
    "image",
    "inReplyTo",
    "likes",
    "location",
    "mediaType",
    "name",
    "nameMap",
    "object",
    "preview",
    "published",
    "replies",
    "sensitive",
    "shares",
    "source",
    "startTime",
    "summary",
    "summaryMap",
    "tag",
    "team",
    "ticketsTrackedBy",
    "to",
    "tracksTicketsFor",
    "updated",
    "url"
  ]

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

  def namespace, do: @namespace
  def type_name, do: @type_name
  def extended_by, do: @extended_by
  def is_or_extends?(type_name), do: Enum.member?(@is_or_extends, type_name)
  def disjoint_with?(type_name), do: Enum.member?(@disjoint_with, type_name)
  def known_property?(prop_name), do: Enum.member?(@known_properties, prop_name)

  def new(opts \\ []) do
    alias = Keyword.get(opts, :alias, "")
    properties = Keyword.get(opts, :properties, %{})
    context = Keyword.get(opts, :context, :simple)

    %__MODULE__{alias: alias, properties: properties}
    |> Fedi.Streams.Utils.as_type_set_json_ld_type(@type_name)
    |> Fedi.Streams.Utils.set_context(context)
  end

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end

  def serialize(%__MODULE__{} = object) do
    Fedi.Streams.BaseType.serialize(object)
  end
end
