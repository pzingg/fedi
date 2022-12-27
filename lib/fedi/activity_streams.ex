defmodule Fedi.ActivityStreams do
  @moduledoc """
  ActivityStreams vocabulary.
  """

  @all_types [
    Fedi.ActivityStreams.Type.Object,
    Fedi.ActivityStreams.Type.Link,
    Fedi.ActivityStreams.Type.Accept,
    Fedi.ActivityStreams.Type.Activity,
    Fedi.ActivityStreams.Type.Add,
    Fedi.ActivityStreams.Type.Announce,
    Fedi.ActivityStreams.Type.Application,
    Fedi.ActivityStreams.Type.Arrive,
    Fedi.ActivityStreams.Type.Article,
    Fedi.ActivityStreams.Type.Audio,
    Fedi.ActivityStreams.Type.Block,
    Fedi.ActivityStreams.Type.Collection,
    Fedi.ActivityStreams.Type.CollectionPage,
    Fedi.ActivityStreams.Type.Create,
    Fedi.ActivityStreams.Type.Delete,
    Fedi.ActivityStreams.Type.Dislike,
    Fedi.ActivityStreams.Type.Document,
    Fedi.ActivityStreams.Type.Event,
    Fedi.ActivityStreams.Type.Flag,
    Fedi.ActivityStreams.Type.Follow,
    Fedi.ActivityStreams.Type.Group,
    Fedi.ActivityStreams.Type.Ignore,
    Fedi.ActivityStreams.Type.Image,
    Fedi.ActivityStreams.Type.IntransitiveActivity,
    Fedi.ActivityStreams.Type.Invite,
    Fedi.ActivityStreams.Type.Join,
    Fedi.ActivityStreams.Type.Leave,
    Fedi.ActivityStreams.Type.Like,
    Fedi.ActivityStreams.Type.Listen,
    Fedi.ActivityStreams.Type.Mention,
    Fedi.ActivityStreams.Type.Move,
    Fedi.ActivityStreams.Type.Note,
    Fedi.ActivityStreams.Type.Offer,
    Fedi.ActivityStreams.Type.OrderedCollection,
    Fedi.ActivityStreams.Type.OrderedCollectionPage,
    Fedi.ActivityStreams.Type.Organization,
    Fedi.ActivityStreams.Type.Page,
    Fedi.ActivityStreams.Type.Person,
    Fedi.ActivityStreams.Type.Place,
    Fedi.ActivityStreams.Type.Profile,
    Fedi.ActivityStreams.Type.Question,
    Fedi.ActivityStreams.Type.Read,
    Fedi.ActivityStreams.Type.Reject,
    Fedi.ActivityStreams.Type.Relationship,
    Fedi.ActivityStreams.Type.Remove,
    Fedi.ActivityStreams.Type.Service,
    Fedi.ActivityStreams.Type.TentativeAccept,
    Fedi.ActivityStreams.Type.TentativeReject,
    Fedi.ActivityStreams.Type.Tombstone,
    Fedi.ActivityStreams.Type.Travel,
    Fedi.ActivityStreams.Type.Undo,
    Fedi.ActivityStreams.Type.Update,
    Fedi.ActivityStreams.Type.Video,
    Fedi.ActivityStreams.Type.View
  ]

  # TODO: implment "contentMap", "nameMap", "summaryMap" (langString versions)
  @all_properties [
    "actor",
    "altitude",
    "attributedTo",
    "audience",
    "bcc",
    "bto",
    "cc",
    "content",
    "context",
    "duration",
    "endTime",
    "generator",
    "icon",
    "image",
    "inReplyTo",
    "instrument",
    "likes",
    "location",
    "mediaType",
    "name",
    "object",
    "origin",
    "preview",
    "published",
    "replies",
    "result",
    "sensitive",
    "shares",
    "source",
    "startTime",
    "summary",
    "tag",
    "target",
    "to",
    "updated",
    "url"
  ]

  @has_map ["content", "name", "summary"]

  def type_modules() do
    @all_types
  end

  def properties() do
    @all_properties
    |> Enum.map(fn prop_name ->
      {initial, rest} = String.split_at(prop_name, 1)
      cap = String.upcase(initial)
      {prop_name, Module.concat([Fedi, ActivityStreams, Property, cap <> rest])}
    end)
  end

  def has_map_property(prop_name), do: Enum.member?(@has_map, prop_name)
end
