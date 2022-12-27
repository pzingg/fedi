defmodule Fedi.ActivityStreams.Property.Units do
  @moduledoc false

  @prop_name "units"

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
    alias = Fedi.Streams.get_alias(alias_map, :activity_streams)

    prop_name =
      case alias do
        "" -> @prop_name
        _ -> alias <> ":" <> @prop_name
      end

    case Map.get(m, prop_name) do
      nil ->
        {:ok, nil}

      i ->
        case Fedi.Streams.Literal.String.deserialize(i) do
          {:ok, v} ->
            {:ok, %__MODULE__{alias: alias, xml_schema_string_member: v, has_string_member: true}}

          _error ->
            case Fedi.Streams.Literal.AnyURI.deserialize(i) do
              {:ok, v} ->
                {:ok, %__MODULE__{alias: alias, xml_schema_any_uri_member: v}}

              _error ->
                {:ok, %__MODULE__{alias: alias, unknown: i}}
            end
        end
    end
  end
end
