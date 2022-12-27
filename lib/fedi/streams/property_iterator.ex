defmodule Fedi.Streams.PropertyIterator do
  @moduledoc false

  require Logger

  def deserialize(namespace, module, i, alias_map, types \\ nil) do
    Fedi.Streams.get_alias(alias_map, namespace)
    |> Fedi.Streams.BaseProperty.deserialize_with_alias(module, i, alias_map, types)
  end

  def deserialize_name(namespace, module, i, alias_map) when is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case Fedi.Streams.BaseProperty.maybe_iri(i) do
      {:ok, uri} ->
        {:ok, struct(module, alias: alias_, iri: uri)}

      _ ->
        case Fedi.Streams.Literal.LangString.deserialize(i) do
          {:ok, v} ->
            {:ok, struct(module, alias: alias_, rdf_lang_string_member: v)}

          _ ->
            case Fedi.Streams.Literal.String.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 struct(module,
                   alias: alias_,
                   xml_schema_string_member: v,
                   has_string_member: true
                 )}

              error ->
                error
            end
        end
    end
    |> case do
      {:ok, this} -> {:ok, this}
      _error -> {:ok, struct(module, alias: alias_, unknown: i)}
    end
  end

  # clear ensures no value of this property is set. Calling
  # is_xml_schema_any_uri afterwards will return false.
  def clear(%{} = prop) do
    %{prop | unknown: nil, member: nil, iri: nil}
  end

  # get returns the value of this property
  def get(%{member: value}) when is_struct(value), do: value
  def get(_), do: nil

  # get_iri returns the IRI of this property. When is_iri returns false,
  # get_iri will return any arbitrary value.
  def get_iri(%{iri: iri} = _prop), do: iri

  # has_any returns true if the value or IRI is set.
  def has_any(%{member: value}) when is_struct(value), do: true
  def has_any(prop), do: is_iri(prop)

  # is_iri returns true if this property is an IRI.
  def is_iri(%{iri: %URI{}}), do: true
  def is_iri(_), do: false

  # json_ld_context returns the JSONLD URIs required in the context string
  # for this property and the specific values that are set. The value
  # in the map is the alias used to import the property's value or
  # values.
  def json_ld_context(%{} = _prop) do
    %{}
  end

  # kind_index computes an arbitrary value for indexing this kind of value.
  # This is a leaky API detail only for folks looking to replace the
  # go-fed implementation. Applications should not use this method.
  def kind_index(prop, types \\ nil)

  def kind_index(%{member: value} = prop, types) when is_struct(value) do
    (types || Fedi.Streams.all_type_modules())
    |> Enum.with_index()
    |> Enum.find(fn {{_prop_name, prop_mod}, _idx} -> value == prop_mod end)
    |> case do
      {{_prop_name, _prop_mod}, idx} -> idx
      nil -> iri_kind_index(prop)
    end
  end

  def kind_index(prop, _), do: iri_kind_index(prop)

  def iri_kind_index(%{iri: %URI{}}), do: -2
  def iri_kind_index(_), do: -1

  def member_value(%{member: value}) when is_struct(value), do: value
  def member_value(_), do: nil

  # less_than compares two instances of this property with an arbitrary but
  # stable comparison. Applications should not use this because it is
  # only meant to help alternative implementations to go-fed to be able
  # to normalize nonfunctional properties.

  def less_than(%{} = prop, %{} = o) do
    idx1 = kind_index(prop)
    idx2 = kind_index(o)

    cond do
      idx1 < idx2 ->
        true

      idx2 < idx1 ->
        false

      idx1 >= 0 ->
        val1 = member_value(prop)
        val2 = member_value(o)
        apply(val1.__struct__, :less_than, [val1, val2])

      true ->
        nil
    end
    |> case do
      lt when is_boolean(lt) ->
        lt

      _ ->
        iri1 = get_iri(prop)
        iri2 = get_iri(o)

        case {iri1, iri2} do
          {nil, nil} -> false
          {nil, _iri} -> true
          {_iri, nil} -> false
          _ -> to_string(iri1) < to_string(iri2)
        end
    end
  end

  # set sets the value of this property. Calling is_xml_schema_any_uri
  # afterwards will return true.
  def set(%{} = prop, member_value) when is_struct(member_value) do
    prop = clear(prop)
    %{prop | member: member_value}
  end

  # set_iri sets the value of this property. Calling is_iri afterwards will
  # return true.
  def set_iri(%{} = prop, %URI{} = v) do
    prop = clear(prop)
    %{prop | iri: v}
  end
end
