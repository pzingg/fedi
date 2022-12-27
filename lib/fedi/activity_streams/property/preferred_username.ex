defmodule Fedi.ActivityStreams.Property.PreferredUsername do
  @moduledoc false

  @prop_name "preferredUsername"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_string_member,
    :rdf_lang_string_member,
    :unknown,
    :iri,
    has_string_member: false
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_string_member: String.t() | nil,
          has_string_member: boolean(),
          rdf_lang_string_member: map() | nil,
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
            case Fedi.Streams.Literal.String.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 %__MODULE__{alias: alias, xml_schema_string_member: v, has_string_member: true}}

              _ ->
                case Fedi.Streams.Literal.LangString.deserialize(i) do
                  {:ok, v} ->
                    {:ok, %__MODULE__{alias: alias, rdf_lang_string_member: v}}

                  error ->
                    error
                end
            end
        end
        |> case do
          {:ok, this} -> {:ok, this}
          _error -> {:ok, %__MODULE__{alias: alias, unknown: i}}
        end
    end
  end
end
