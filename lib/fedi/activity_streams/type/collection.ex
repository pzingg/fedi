defmodule Fedi.ActivityStreams.Type.Collection do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  A Collection is a subtype of Object that represents ordered or unordered sets
  of Object or Link instances. Refer to the Activity Streams 2.0 Core
  specification for a complete description of the Collection type.
  """

  @namespace :activity_streams
  @type_name "Collection"
  @extended_by [
    "CollectionPage",
    "OrderedCollection",
    "OrderedCollectionPage",
    "OrderedCollectionPage"
  ]
  @is_or_extends [
    "Collection",
    "Object"
  ]
  @disjoint_with [
    "Hashtag",
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
    "current",
    "duration",
    "endTime",
    "first",
    "generator",
    "icon",
    "image",
    "inReplyTo",
    "items",
    "last",
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
    "to",
    "totalItems",
    "updated",
    "url"
  ]

  @enforce_keys [:alias]
  defstruct [
    :alias,
    properties: %{},
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          properties: map(),
          unknown: map()
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

  def deserialize(m, context) when is_map(m) and is_map(context) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, context)
  end

  def serialize(%__MODULE__{} = object) do
    Fedi.Streams.BaseType.serialize(object)
  end
end
