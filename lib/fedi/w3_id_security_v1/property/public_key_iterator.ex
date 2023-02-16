defmodule Fedi.W3IDSecurityV1.Property.PublicKeyIterator do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  Iterator for the W3IDSecurityV1 "publicKey" property.
  """

  @namespace :w3_id_security_v1
  @range [:iri, :object]
  @domain [
    {"Application", Fedi.W3IDSecurityV1.Type.Application},
    {"Group", Fedi.W3IDSecurityV1.Type.Group},
    {"Organization", Fedi.W3IDSecurityV1.Type.Organization},
    {"Person", Fedi.W3IDSecurityV1.Type.Person},
    {"Service", Fedi.W3IDSecurityV1.Type.Service}
  ]
  @prop_name "publicKey"

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
  def parent_module, do: Fedi.W3IDSecurityV1.Property.PublicKey

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
