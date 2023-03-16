defmodule Fedi.ActivityStreams.Type.Service do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Represents a service of any kind.
  """

  @namespace :activity_streams
  @type_name "Service"
  @extended_by []
  @is_or_extends [
    "Service",
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
    "discoverable",
    "duration",
    "endTime",
    "featured",
    "followers",
    "following",
    "generator",
    "icon",
    "image",
    "inReplyTo",
    "inbox",
    "liked",
    "likes",
    "location",
    "manuallyApprovesFollowers",
    "mediaType",
    "name",
    "nameMap",
    "object",
    "outbox",
    "preferredUsername",
    "preferredUsernameMap",
    "preview",
    "publicKey",
    "published",
    "replies",
    "sensitive",
    "shares",
    "source",
    "startTime",
    "streams",
    "summary",
    "summaryMap",
    "tag",
    "to",
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
