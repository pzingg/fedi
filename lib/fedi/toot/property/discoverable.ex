defmodule Fedi.Toot.Property.Discoverable do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The Toot "discoverable" property.
  """

  @namespace :toot
  @range [:boolean]
  @domain [
    {"Application", Fedi.Toot.Type.Application},
    {"Group", Fedi.Toot.Type.Group},
    {"Organization", Fedi.Toot.Type.Organization},
    {"Person", Fedi.Toot.Type.Person},
    {"Service", Fedi.Toot.Type.Service}
  ]
  @prop_name "discoverable"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_boolean_member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_boolean_member: boolean() | nil,
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
