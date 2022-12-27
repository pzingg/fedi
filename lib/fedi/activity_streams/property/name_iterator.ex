defmodule Fedi.ActivityStreams.Property.NameIterator do
  @moduledoc """
  ActivityStreamsActorPropertyIterator is an iterator for a property. It is
  permitted to be one of multiple value types. At most, one type of value can
  be present, or none at all. Setting a value will clear the other types of
  values so that only one of the 'Is' methods will return true. It is
  possible to clear all values, so that this property is empty.
  """

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :xml_schema_string_member,
    :has_string_member,
    :rdf_lang_string_member,
    :unknown,
    :iri
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          xml_schema_string_member: String.t() | nil,
          has_string_member: boolean(),
          rdf_lang_string_member: map() | nil,
          unknown: term(),
          iri: URI.t() | nil
        }

  def deserialize(i, alias_map) when is_map(alias_map) do
    alias = Fedi.Streams.get_alias(alias_map, :activity_streams)

    case Fedi.Streams.BaseProperty.maybe_iri(i) do
      {:ok, uri} ->
        {:ok, %__MODULE__{alias: alias, iri: uri}}

      _ ->
        case Fedi.Streams.Literal.String.deserialize(i) do
          {:ok, v} ->
            {:ok, %__MODULE__{alias: alias, xml_schema_string_member: v, has_string_member: true}}

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
