defmodule Fedi.W3IDSecurityV1.Property.PublicKey do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The public key for an ActivityStreams actor
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
  def iterator_module, do: Fedi.W3IDSecurityV1.Property.PublicKeyIterator
  def parent_module, do: nil

  def new(alias_ \\ "") do
    %__MODULE__{alias: alias_}
  end

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_values(
      @namespace,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize(prop)
  end
end
