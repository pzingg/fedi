defmodule Fedi.ActivityStreams.Property.Shares do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  This is a list of all Announce activities with this object as the object
  property
  """

  @namespace :activity_streams
  @range [:iri, :object]
  @domain [
    {"Accept", Fedi.ActivityStreams.Type.Accept},
    {"Activity", Fedi.ActivityStreams.Type.Activity},
    {"Add", Fedi.ActivityStreams.Type.Add},
    {"Announce", Fedi.ActivityStreams.Type.Announce},
    {"Application", Fedi.ActivityStreams.Type.Application},
    {"Article", Fedi.ActivityStreams.Type.Article},
    {"Audio", Fedi.ActivityStreams.Type.Audio},
    {"Collection", Fedi.ActivityStreams.Type.Collection},
    {"CollectionPage", Fedi.ActivityStreams.Type.CollectionPage},
    {"Create", Fedi.ActivityStreams.Type.Create},
    {"Delete", Fedi.ActivityStreams.Type.Delete},
    {"Dislike", Fedi.ActivityStreams.Type.Dislike},
    {"Document", Fedi.ActivityStreams.Type.Document},
    {"Emoji", Fedi.Toot.Type.Emoji},
    {"Event", Fedi.ActivityStreams.Type.Event},
    {"Flag", Fedi.ActivityStreams.Type.Flag},
    {"Follow", Fedi.ActivityStreams.Type.Follow},
    {"Group", Fedi.ActivityStreams.Type.Group},
    {"IdentityProof", Fedi.Toot.Type.IdentityProof},
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
    {"Read", Fedi.ActivityStreams.Type.Read},
    {"Reject", Fedi.ActivityStreams.Type.Reject},
    {"Relationship", Fedi.ActivityStreams.Type.Relationship},
    {"Remove", Fedi.ActivityStreams.Type.Remove},
    {"Service", Fedi.ActivityStreams.Type.Service},
    {"Tombstone", Fedi.ActivityStreams.Type.Tombstone},
    {"Undo", Fedi.ActivityStreams.Type.Undo},
    {"Update", Fedi.ActivityStreams.Type.Update},
    {"Video", Fedi.ActivityStreams.Type.Video},
    {"View", Fedi.ActivityStreams.Type.View}
  ]
  @prop_name "shares"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          member: term(),
          iri: URI.t() | nil,
          unknown: map()
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

  def deserialize(m, context) when is_map(m) and is_map(context) do
    Fedi.Streams.BaseProperty.deserialize(
      @namespace,
      __MODULE__,
      @range,
      @prop_name,
      m,
      context
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
