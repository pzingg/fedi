defmodule Fedi.ActivityStreams.Type.Link do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  A Link is an indirect, qualified reference to a resource identified by a URL.
  The fundamental model for links is established by [RFC5988]. Many of the
  properties defined by the Activity Vocabulary allow values that are either
  instances of Object or Link. When a Link is used, it establishes a qualified
  relation connecting the subject (the containing object) to the resource
  identified by the href. Properties of the Link are properties of the reference
  as opposed to properties of the resource.
  """

  @namespace :activity_streams
  @type_name "Link"
  @extended_by [
    "Mention"
  ]
  @is_or_extends [
    "Link"
  ]
  @disjoint_with [
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
    "Object",
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
  @known_properties [
    "attributedTo",
    "height",
    "href",
    "hreflang",
    "mediaType",
    "name",
    "nameMap",
    "preview",
    "rel",
    "summary",
    "summaryMap",
    "width"
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
