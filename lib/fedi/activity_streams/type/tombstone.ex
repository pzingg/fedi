defmodule Fedi.ActivityStreams.Type.Tombstone do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  A Tombstone represents a content object that has been deleted. It can be used
  in Collections to signify that there used to be an object at this position,
  but it has been deleted.
  """

  @namespace :activity_streams
  @type_name "Tombstone"
  @extended_by []
  @is_or_extends [
    "Tombstone",
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
    "deleted",
    "duration",
    "endTime",
    "formerType",
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
