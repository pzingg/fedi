defmodule Fedi.ActivityStreams.Property.Subject do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  On a Relationship object, the subject property identifies one of the connected
  individuals. For instance, for a Relationship object describing "John is
  related to Sally", subject would refer to John.
  """

  @namespace :activity_streams
  @range [:iri, :object]
  @domain [
    {"Relationship", Fedi.ActivityStreams.Type.Relationship},
    {"TicketDependency", Fedi.ActivityStreams.Type.TicketDependency}
  ]
  @prop_name "subject"

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
