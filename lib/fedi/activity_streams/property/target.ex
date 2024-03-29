defmodule Fedi.ActivityStreams.Property.Target do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Describes the indirect object, or target, of the activity. The precise meaning
  of the target is largely dependent on the type of action being described but
  will often be the object of the English preposition "to". For instance, in the
  activity "John added a movie to his wishlist", the target of the activity is
  John's wishlist. An activity can have more than one target.
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
  @prop_name "target"

  @enforce_keys :alias
  defstruct [
    :alias,
    values: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          values: list()
        }

  def prop_name, do: @prop_name
  def range, do: @range
  def domain, do: @domain
  def functional?, do: false
  def iterator_module, do: Fedi.ActivityStreams.Property.TargetIterator
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, context) when is_map(m) and is_map(context) do
    Fedi.Streams.BaseProperty.deserialize_values(
      @namespace,
      __MODULE__,
      @prop_name,
      m,
      context
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
