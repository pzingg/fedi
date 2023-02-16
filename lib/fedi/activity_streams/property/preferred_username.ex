defmodule Fedi.ActivityStreams.Property.PreferredUsername do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  A short username which may be used to refer to the actor, with no uniqueness
  guarantees
  """

  @namespace :activity_streams
  @range [:lang_string, :string]
  @domain [
    {"Application", Fedi.ActivityStreams.Type.Application},
    {"Group", Fedi.ActivityStreams.Type.Group},
    {"Organization", Fedi.ActivityStreams.Type.Organization},
    {"Person", Fedi.ActivityStreams.Type.Person},
    {"Service", Fedi.ActivityStreams.Type.Service}
  ]
  @prop_name ["preferredUsername", "preferredUsernameMap"]

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_string_member,
    :rdf_lang_string_member,
    :iri,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_string_member: String.t() | nil,
          rdf_lang_string_member: map() | nil,
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
