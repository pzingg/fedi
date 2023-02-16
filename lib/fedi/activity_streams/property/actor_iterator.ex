defmodule Fedi.ActivityStreams.Property.ActorIterator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Iterator for the ActivityStreams "actor" property.
  """

  @namespace :activity_streams
  @range [:iri, :object]
  @domain [
    {"Accept", Fedi.ActivityStreams.Type.Accept},
    {"Activity", Fedi.ActivityStreams.Type.Activity},
    {"Add", Fedi.ActivityStreams.Type.Add},
    {"Announce", Fedi.ActivityStreams.Type.Announce},
    {"Arrive", Fedi.ActivityStreams.Type.Arrive},
    {"Block", Fedi.ActivityStreams.Type.Block},
    {"Create", Fedi.ActivityStreams.Type.Create},
    {"Delete", Fedi.ActivityStreams.Type.Delete},
    {"Dislike", Fedi.ActivityStreams.Type.Dislike},
    {"Flag", Fedi.ActivityStreams.Type.Flag},
    {"Follow", Fedi.ActivityStreams.Type.Follow},
    {"Ignore", Fedi.ActivityStreams.Type.Ignore},
    {"IntransitiveActivity", Fedi.ActivityStreams.Type.IntransitiveActivity},
    {"Invite", Fedi.ActivityStreams.Type.Invite},
    {"Join", Fedi.ActivityStreams.Type.Join},
    {"Leave", Fedi.ActivityStreams.Type.Leave},
    {"Like", Fedi.ActivityStreams.Type.Like},
    {"Listen", Fedi.ActivityStreams.Type.Listen},
    {"Move", Fedi.ActivityStreams.Type.Move},
    {"Offer", Fedi.ActivityStreams.Type.Offer},
    {"Push", Fedi.ActivityStreams.Type.Push},
    {"Question", Fedi.ActivityStreams.Type.Question},
    {"Read", Fedi.ActivityStreams.Type.Read},
    {"Reject", Fedi.ActivityStreams.Type.Reject},
    {"Remove", Fedi.ActivityStreams.Type.Remove},
    {"TentativeAccept", Fedi.ActivityStreams.Type.TentativeAccept},
    {"TentativeReject", Fedi.ActivityStreams.Type.TentativeReject},
    {"Travel", Fedi.ActivityStreams.Type.Travel},
    {"Undo", Fedi.ActivityStreams.Type.Undo},
    {"Update", Fedi.ActivityStreams.Type.Update},
    {"View", Fedi.ActivityStreams.Type.View}
  ]
  @prop_name "actor"

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
  def functional?, do: false
  def iterator_module, do: nil
  def parent_module, do: Fedi.ActivityStreams.Property.Actor

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(prop_name, mapped_property?, i, alias_map) when is_map(alias_map) do
    Fedi.Streams.PropertyIterator.deserialize(
      @namespace,
      __MODULE__,
      @range,
      prop_name,
      mapped_property?,
      i,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
