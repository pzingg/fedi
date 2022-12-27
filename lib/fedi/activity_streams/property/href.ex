defmodule Fedi.ActivityStreams.Property.Href do
  @moduledoc false

  @prop_name "href"

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
        case Fedi.Streams.Literal.AnyURI.deserialize(i) do
          {:ok, v} ->
            {:ok, %__MODULE__{alias: alias, xml_schema_any_uri_member: v}}

          _error ->
            {:ok, %__MODULE__{alias: alias, unknown: i}}
        end
    end
  end
end
