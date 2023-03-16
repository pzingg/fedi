defmodule Fedi.W3IDSecurityV1.Property.Owner do
  # This module was generated from an ontology. DO NOT EDIT!
  # Run `mix help ontology.gen` for details.

  @moduledoc """
  The owner of the public key for an ActivityStreams actor
  """

  @namespace :w3_id_security_v1
  @range [:any_uri]
  @domain [
    {"PublicKey", Fedi.W3IDSecurityV1.Type.PublicKey}
  ]
  @prop_name "owner"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xsd_any_uri_member,
    unknown: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xsd_any_uri_member: URI.t() | nil,
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
