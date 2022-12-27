defmodule Fedi.ActivityStreams.Manager do
  @moduledoc """
  Manager manages interface S and deserializations for use by generated code.
  Application code implicitly uses this manager at run-time to create
  concrete implementations of the interfaces.
  """

  alias Fedi.JSON.LD.Property.Id, as: LDId
  alias Fedi.JSON.LD.Property.Type, as: LDType

  alias Fedi.ActivityStreams.Property.Accuracy
  alias Fedi.ActivityStreams.Property.Actor
  alias Fedi.ActivityStreams.Property.Altitude
  alias Fedi.ActivityStreams.Property.AnyOf
  alias Fedi.ActivityStreams.Property.Attachment
  alias Fedi.ActivityStreams.Property.AttributedTo
  alias Fedi.ActivityStreams.Property.Audience
  alias Fedi.ActivityStreams.Property.Bcc
  alias Fedi.ActivityStreams.Property.Bto
  alias Fedi.ActivityStreams.Property.Cc
  alias Fedi.ActivityStreams.Property.Closed
  alias Fedi.ActivityStreams.Property.Content
  alias Fedi.ActivityStreams.Property.Context
  alias Fedi.ActivityStreams.Property.Current
  alias Fedi.ActivityStreams.Property.Deleted
  alias Fedi.ActivityStreams.Property.Describes
  alias Fedi.ActivityStreams.Property.Duration
  alias Fedi.ActivityStreams.Property.Endtime
  alias Fedi.ActivityStreams.Property.First
  alias Fedi.ActivityStreams.Property.Followers
  alias Fedi.ActivityStreams.Property.Following
  alias Fedi.ActivityStreams.Property.FormerType
  alias Fedi.ActivityStreams.Property.Generator
  alias Fedi.ActivityStreams.Property.Height
  alias Fedi.ActivityStreams.Property.Href
  alias Fedi.ActivityStreams.Property.Hreflang
  alias Fedi.ActivityStreams.Property.Icon
  alias Fedi.ActivityStreams.Property.Image
  alias Fedi.ActivityStreams.Property.Inbox
  alias Fedi.ActivityStreams.Property.InReplyTo
  alias Fedi.ActivityStreams.Property.Instrument
  alias Fedi.ActivityStreams.Property.Items
  alias Fedi.ActivityStreams.Property.Last
  alias Fedi.ActivityStreams.Property.Latitude
  alias Fedi.ActivityStreams.Property.Liked
  alias Fedi.ActivityStreams.Property.Likes
  alias Fedi.ActivityStreams.Property.Location
  alias Fedi.ActivityStreams.Property.Longitude
  alias Fedi.ActivityStreams.Property.ManuallyApprovesFollowers
  alias Fedi.ActivityStreams.Property.MediaType
  alias Fedi.ActivityStreams.Property.Name
  alias Fedi.ActivityStreams.Property.Next
  alias Fedi.ActivityStreams.Property.Object
  alias Fedi.ActivityStreams.Property.OneOf
  alias Fedi.ActivityStreams.Property.OrderedItems
  alias Fedi.ActivityStreams.Property.Origin
  alias Fedi.ActivityStreams.Property.Outbox
  alias Fedi.ActivityStreams.Property.PartOf
  alias Fedi.ActivityStreams.Property.PreferredUsername
  alias Fedi.ActivityStreams.Property.Prev
  alias Fedi.ActivityStreams.Property.Preview
  alias Fedi.ActivityStreams.Property.Published
  alias Fedi.ActivityStreams.Property.Radius
  alias Fedi.ActivityStreams.Property.Rel
  alias Fedi.ActivityStreams.Property.Relationship
  alias Fedi.ActivityStreams.Property.Replies
  alias Fedi.ActivityStreams.Property.Result
  alias Fedi.ActivityStreams.Property.Sensitive
  alias Fedi.ActivityStreams.Property.Shares
  alias Fedi.ActivityStreams.Property.Source
  alias Fedi.ActivityStreams.Property.StartIndex
  alias Fedi.ActivityStreams.Property.StartTime
  alias Fedi.ActivityStreams.Property.Streams
  alias Fedi.ActivityStreams.Property.Subject
  alias Fedi.ActivityStreams.Property.Summary
  alias Fedi.ActivityStreams.Property.Tag
  alias Fedi.ActivityStreams.Property.Target
  alias Fedi.ActivityStreams.Property.To
  alias Fedi.ActivityStreams.Property.TotalItems
  alias Fedi.ActivityStreams.Property.Units
  alias Fedi.ActivityStreams.Property.Updated
  alias Fedi.ActivityStreams.Property.Url
  alias Fedi.ActivityStreams.Property.Width

  alias ActivityStreams.Type.Accept
  alias ActivityStreams.Type.Activity
  alias ActivityStreams.Type.Add
  alias ActivityStreams.Type.Announce
  alias ActivityStreams.Type.Application
  alias ActivityStreams.Type.Arrive
  alias ActivityStreams.Type.Article
  alias ActivityStreams.Type.Audio
  alias ActivityStreams.Type.Block
  alias ActivityStreams.Type.Collection
  alias ActivityStreams.Type.CollectionPage
  alias ActivityStreams.Type.Create
  alias ActivityStreams.Type.Delete
  alias ActivityStreams.Type.Dislike
  alias ActivityStreams.Type.Document
  alias ActivityStreams.Type.Event
  alias ActivityStreams.Type.Flag
  alias ActivityStreams.Type.Follow
  alias ActivityStreams.Type.Group
  alias ActivityStreams.Type.Ignore
  alias ActivityStreams.Type.Image
  alias ActivityStreams.Type.IntransitiveActivity
  alias ActivityStreams.Type.Invite
  alias ActivityStreams.Type.Join
  alias ActivityStreams.Type.Leave
  alias ActivityStreams.Type.Like
  alias ActivityStreams.Type.Link
  alias ActivityStreams.Type.Listen
  alias ActivityStreams.Type.Mention
  alias ActivityStreams.Type.Move
  alias ActivityStreams.Type.Note
  alias ActivityStreams.Type.Object
  alias ActivityStreams.Type.Offer
  alias ActivityStreams.Type.OrderedCollection
  alias ActivityStreams.Type.OrderedCollectionPage
  alias ActivityStreams.Type.Organization
  alias ActivityStreams.Type.Page
  alias ActivityStreams.Type.Person
  alias ActivityStreams.Type.Place
  alias ActivityStreams.Type.Profile
  alias ActivityStreams.Type.Question
  alias ActivityStreams.Type.Read
  alias ActivityStreams.Type.Reject
  alias ActivityStreams.Type.Relationship
  alias ActivityStreams.Type.Remove
  alias ActivityStreams.Type.Service
  alias ActivityStreams.Type.TentativeAccept
  alias ActivityStreams.Type.TentativeReject
  alias ActivityStreams.Type.Tombstone
  alias ActivityStreams.Type.Travel
  alias ActivityStreams.Type.Undo
  alias ActivityStreams.Type.Update
  alias ActivityStreams.Type.Video
  alias ActivityStreams.Type.View

  def deserialize_id(m, alias_map), do: apply(LDId, :deserialize, [m, alias_map])
  def deserialize_type(m, alias_map), do: apply(LDType, :deserialize, [m, alias_map])
  def deserialize_accuracy(m, alias_map), do: apply(Accuracy, :deserialize, [m, alias_map])
  def deserialize_accept(m, alias_map), do: apply(Accept, :deserialize, [m, alias_map])
end
