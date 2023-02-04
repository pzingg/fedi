defmodule Fedi.ActivityStreams.Property.Updated do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The date and time at which the object was updated
  """

  @namespace :activity_streams
  @range [:date_time]
  @domain [
    {"Accept", Fedi.ActivityStreams.Type.Accept},
    {"Activity", Fedi.ActivityStreams.Type.Activity},
    {"Add", Fedi.ActivityStreams.Type.Add},
    {"Announce", Fedi.ActivityStreams.Type.Announce},
    {"Application", Fedi.ActivityStreams.Type.Application},
    {"Article", Fedi.ActivityStreams.Type.Article},
    {"Audio", Fedi.ActivityStreams.Type.Audio},
    {"Branch", Fedi.ActivityStreams.Type.Branch},
    {"Collection", Fedi.ActivityStreams.Type.Collection},
    {"CollectionPage", Fedi.ActivityStreams.Type.CollectionPage},
    {"Commit", Fedi.ActivityStreams.Type.Commit},
    {"Create", Fedi.ActivityStreams.Type.Create},
    {"Delete", Fedi.ActivityStreams.Type.Delete},
    {"Dislike", Fedi.ActivityStreams.Type.Dislike},
    {"Document", Fedi.ActivityStreams.Type.Document},
    {"Emoji", Fedi.ActivityStreams.Type.Emoji},
    {"Event", Fedi.ActivityStreams.Type.Event},
    {"Flag", Fedi.ActivityStreams.Type.Flag},
    {"Follow", Fedi.ActivityStreams.Type.Follow},
    {"Group", Fedi.ActivityStreams.Type.Group},
    {"IdentityProof", Fedi.ActivityStreams.Type.IdentityProof},
    {"Ignore", Fedi.ActivityStreams.Type.Ignore},
    {"Image", Fedi.ActivityStreams.Type.Image},
    {"IntransitiveActivity", Fedi.ActivityStreams.Type.IntransitiveActivity},
    {"Join", Fedi.ActivityStreams.Type.Join},
    {"Leave", Fedi.ActivityStreams.Type.Leave},
    {"Like", Fedi.ActivityStreams.Type.Like},
    {"Listen", Fedi.ActivityStreams.Type.Listen},
    {"Move", Fedi.ActivityStreams.Type.Move},
    {"Note", Fedi.ActivityStreams.Type.Note},
    {"Object", Fedi.ActivityStreams.Type.Object},
    {"Offer", Fedi.ActivityStreams.Type.Offer},
    {"OrderedCollection", Fedi.ActivityStreams.Type.OrderedCollection},
    {"Organization", Fedi.ActivityStreams.Type.Organization},
    {"Page", Fedi.ActivityStreams.Type.Page},
    {"Person", Fedi.ActivityStreams.Type.Person},
    {"Place", Fedi.ActivityStreams.Type.Place},
    {"Profile", Fedi.ActivityStreams.Type.Profile},
    {"Push", Fedi.ActivityStreams.Type.Push},
    {"Read", Fedi.ActivityStreams.Type.Read},
    {"Reject", Fedi.ActivityStreams.Type.Reject},
    {"Relationship", Fedi.ActivityStreams.Type.Relationship},
    {"Remove", Fedi.ActivityStreams.Type.Remove},
    {"Repository", Fedi.ActivityStreams.Type.Repository},
    {"Service", Fedi.ActivityStreams.Type.Service},
    {"Ticket", Fedi.ActivityStreams.Type.Ticket},
    {"TicketDependency", Fedi.ActivityStreams.Type.TicketDependency},
    {"Tombstone", Fedi.ActivityStreams.Type.Tombstone},
    {"Undo", Fedi.ActivityStreams.Type.Undo},
    {"Update", Fedi.ActivityStreams.Type.Update},
    {"Video", Fedi.ActivityStreams.Type.Video},
    {"View", Fedi.ActivityStreams.Type.View}
  ]
  @prop_name "updated"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    :xsd_date_time_member,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          unknown: term(),
          xsd_date_time_member: DateTime.t() | nil,
          iri: URI.t() | nil
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: true
  def iterator_module, do: nil
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @range,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
