defmodule SecurityV1.Property.Owner do
  @moduledoc false

  @prop_name "owner"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_any_uri_member,
    :unknown
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_any_uri_member: URI.t(),
          unknown: term()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, :security_v1)

    case Fedi.Streams.BaseProperty.get_prop(m, @prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        case Fedi.Streams.Literal.AnyURI.deserialize(i) do
          {:ok, v} ->
            {:ok, %__MODULE__{alias: alias_, xml_schema_any_uri_member: v}}

          _error ->
            {:ok, %__MODULE__{alias: alias_, unknown: i}}
        end
    end
  end
end
