defmodule Fedi.ActivityStreams.Property.Hreflang do
  @moduledoc false

  @prop_name "hreflang"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_bcp_47_member,
    :has_bcp_47_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_bcp_47_member: String.t(),
          has_bcp_47_member: boolean(),
          unknown: term(),
          iri: URI.t() | nil
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, :activity_streams)

    case Fedi.Streams.BaseProperty.get_prop(m, @prop_name, alias_) do
      nil ->
        {:ok, nil}

      i ->
        case Fedi.Streams.BaseProperty.maybe_iri(i) do
          {:ok, uri} ->
            {:ok, %__MODULE__{alias: alias_, iri: uri}}

          _ ->
            case Fedi.Streams.Literal.Bcp47.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 %__MODULE__{alias: alias_, xml_schema_bcp_47_member: v, has_bcp_47_member: true}}

              _ ->
                :error
            end
        end
        |> case do
          {:ok, this} -> {:ok, this}
          _error -> {:ok, %__MODULE__{alias: alias_, unknown: i}}
        end
    end
  end
end
