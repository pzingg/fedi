defmodule Fedi.ActivityStreams.Property.EndTime do
  @moduledoc false

  @prop_name "endTime"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_date_time_member,
    :has_date_time_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_date_time_member: DateTime.t(),
          has_date_time_member: boolean(),
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
            case Fedi.Streams.Literal.DateTime.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 %__MODULE__{
                   alias: alias_,
                   xml_schema_date_time_member: v,
                   has_date_time_member: true
                 }}

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
