defmodule SecurityV1.Property.PublicKeyPem do
  @moduledoc false

  @prop_name "publicKeyPem"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_string_member,
    :xml_schema_any_uri_member,
    :unknown,
    has_string_member: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_string_member: String.t() | nil,
          has_string_member: boolean(),
          xml_schema_any_uri_member: URI.t() | nil,
          unknown: term()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_string(
      :security_v1,
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
