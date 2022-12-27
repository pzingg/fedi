defmodule Fedi.ActivityStreams.Property.Altitude do
  @moduledoc false

  @prop_name "altitude"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_float_member,
    :has_float_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_float_member: float(),
          has_float_member: boolean(),
          unknown: term(),
          iri: URI.t() | nil
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
        case Fedi.Streams.BaseProperty.maybe_iri(i) do
          {:ok, uri} ->
            {:ok, %__MODULE__{alias: alias, iri: uri}}

          _ ->
            case Fedi.Streams.Literal.Float.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 %__MODULE__{alias: alias, xml_schema_float_member: v, has_float_member: true}}

              _ ->
                :error
            end
        end
        |> case do
          {:ok, this} -> {:ok, this}
          _error -> {:ok, %__MODULE__{alias: alias, unknown: i}}
        end
    end
  end
end
