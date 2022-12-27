defmodule Fedi.ActivityStreams.Property.Duration do
  @moduledoc false

  @prop_name "duration"

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_duration_member,
    :has_duration_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_duration_member: Timex.Duration.t(),
          has_duration_member: boolean(),
          unknown: term(),
          iri: URI.t() | nil
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, :activity_streams)

    case Fedi.Streams.BaseProperty.get_prop(m, @prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        case Fedi.Streams.BaseProperty.maybe_iri(i) do
          {:ok, uri} ->
            {:ok, %__MODULE__{alias: alias_, iri: uri}}

          _ ->
            case Fedi.Streams.Literal.Duration.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 %__MODULE__{
                   alias: alias_,
                   xml_schema_duration_member: v,
                   has_duration_member: true
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

  def serialize(%{xml_schema_duration_member: %Timex.Duration{} = duration}) do
    Fedi.Streams.Literal.Duration.serialize(duration)
  end

  def serialize(%{iri: %URI{} = iri}) do
    to_string(iri)
  end

  def serialize(%{unknown: unknown}) do
    unknown
  end
end
