defmodule Fedi.Streams.BaseProperty do
  @moduledoc false

  require Logger

  def deserialize(namespace, module, prop_name, m, alias_map, types \\ nil)

  def deserialize(namespace, module, prop_name, m, alias_map, types) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case Fedi.Streams.BaseProperty.get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        deserialize_with_alias(alias_, module, i, alias_map, types)
    end
  end

  def deserialize_string(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case Fedi.Streams.BaseProperty.get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        case Fedi.Streams.Literal.AnyURI.deserialize(i) do
          {:ok, v} ->
            {:ok, struct(module, alias: alias_, xml_schema_any_uri_member: v)}

          _ ->
            case Fedi.Streams.Literal.String.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 struct(module,
                   alias: alias_,
                   xml_schema_string_member: v,
                   has_string_member: true
                 )}

              _error ->
                {:ok, struct(module, alias: alias_, unknown: i)}
            end
        end
    end
  end

  def deserialize_uri(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case Fedi.Streams.BaseProperty.get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        case Fedi.Streams.Literal.AnyURI.deserialize(i) do
          {:ok, v} ->
            {:ok, struct(module, alias: alias_, xml_schema_any_uri_member: v)}

          _error ->
            {:ok, struct(module, alias: alias_, unknown: i)}
        end
    end
  end

  def deserialize_nni(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        case maybe_iri(i) do
          {:ok, uri} ->
            {:ok, struct(module, alias: alias_, iri: uri)}

          _ ->
            case Fedi.Streams.Literal.NonNegInteger.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 struct(module,
                   alias: alias_,
                   xml_schema_non_neg_integer_member: v,
                   has_non_neg_integer_member: true
                 )}

              _ ->
                :error
            end
        end
        |> case do
          {:ok, this} -> {:ok, this}
          _error -> {:ok, struct(module, alias: alias_, unknown: i)}
        end
    end
  end

  def deserialize_float(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        case maybe_iri(i) do
          {:ok, uri} ->
            {:ok, struct(module, alias: alias_, iri: uri)}

          _ ->
            case Fedi.Streams.Literal.Float.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 struct(module, alias: alias_, xml_schema_float_member: v, has_float_member: true)}

              _ ->
                :error
            end
        end
        |> case do
          {:ok, this} -> {:ok, this}
          _error -> {:ok, struct(module, alias: alias_, unknown: i)}
        end
    end
  end

  def deserialize_date_time(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      {i, _prop_name, _is_map} ->
        case Fedi.Streams.BaseProperty.maybe_iri(i) do
          {:ok, uri} ->
            {:ok, struct(module, alias: alias_, iri: uri)}

          _ ->
            case Fedi.Streams.Literal.DateTime.deserialize(i) do
              {:ok, v} ->
                {:ok,
                 struct(module,
                   alias: alias_,
                   xml_schema_date_time_member: v,
                   has_date_time_member: true
                 )}

              _ ->
                :error
            end
        end
        |> case do
          {:ok, this} -> {:ok, this}
          _error -> {:ok, struct(module, alias: alias_, unknown: i)}
        end
    end
  end

  def deserialize_values(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    iterator_module =
      Module.split(module)
      |> List.update_at(-1, fn name -> name <> "Iterator" end)
      |> Module.concat()

    case get_values(m, prop_name, alias_) do
      [] ->
        {:ok, nil}

      values ->
        result =
          values
          |> Enum.reduce_while({[], []}, fn {i, prop_name, mapped_property?}, {map_acc, acc} ->
            case apply(iterator_module, :deserialize, [i, alias_map]) do
              {:ok, value} ->
                if mapped_property? do
                  {:cont, {[value | map_acc], acc}}
                else
                  {:cont, {map_acc, [value | acc]}}
                end

              {:error, reason} ->
                Logger.error("Error iterating #{prop_name}: #{reason}")
                {:halt, {:error, reason}}
            end
          end)

        case result do
          {:error, reason} ->
            {:error, reason}

          {mapped_values, values} ->
            mapped_values = Enum.reverse(mapped_values)
            values = Enum.reverse(values)

            if Enum.empty?(mapped_values) do
              {:ok, struct(module, alias: alias_, values: values)}
            else
              {:ok,
               struct(module,
                 alias: alias_,
                 mapped_values: mapped_values,
                 values: values
               )}
            end
        end
    end
  end

  def deserialize_with_alias(alias_, module, i, alias_map, types) do
    case maybe_iri(i) do
      {:ok, uri} ->
        {:ok, struct(module, alias: alias_, iri: uri)}

      _ ->
        deserialize_types(alias_, module, i, alias_map, types)
    end
    |> case do
      {:ok, this} -> {:ok, this}
      _ -> {:ok, struct(module, alias: alias_, unknown: i)}
    end
  end

  def deserialize_types(alias_, module, i, alias_map, types \\ nil)

  def deserialize_types(alias_, module, i, alias_map, types) when is_map(i) do
    (types || Fedi.Streams.all_type_modules())
    |> Enum.reduce_while(:error, fn type_mod, acc ->
      case apply(type_mod, :deserialize, [i, alias_map]) do
        {:ok, v} when is_struct(v) ->
          {:halt, {:ok, struct(module, alias: alias_, member: v)}}

        {:ok, v} ->
          Logger.error("deserialize_types did not return a struct: #{inspect(v)}")
          {:cont, acc}

        _ ->
          {:cont, acc}
      end
    end)
  end

  def deserialize_types(_, _, _, _, _), do: :error

  ##### Serialization

  # serialize converts this into an interface representation suitable for
  # marshalling into a text or binary format. Applications should not
  # need this function as most typical use cases serialize types
  # instead of individual properties. It is exposed for alternatives to
  # go-fed implementations to use.
  def serialize_values(prop) do
    result =
      Enum.reduce_while(prop.properties, [], fn it, acc ->
        case serialize(it) do
          {:error, reason} -> {:halt, {:error, reason}}
          {:ok, b} -> {:cont, [b | acc]}
        end
      end)

    case result do
      {:error, reason} -> {:error, reason}
      # Shortcut: if serializing one value, don't return an array -- pretty sure other Fediverse software would choke on a "type" value with array, for example.
      [v] -> {:ok, v}
      l -> {:ok, Enum.reverse(l)}
    end
  end

  def serialize_mapped_values(prop) do
    case serialize_values(prop) do
      {:error, reason} ->
        {:error, reason}

      {:ok, unmapped} ->
        result =
          Enum.reduce_while(prop.mapped_values, [], fn it, acc ->
            case serialize(it) do
              {:error, reason} -> {:halt, {:error, reason}}
              {:ok, b} -> {:cont, [b | acc]}
            end
          end)

        case result do
          {:error, reason} ->
            {:error, reason}

          [mapped] ->
            # Shortcut: if serializing one value, don't return an array -- pretty sure other Fediverse software would choke on a "type" value with array, for example.
            {:ok, %Fedi.Streams.MappedNameProp{mapped: mapped, unmapped: unmapped}}

          mapped ->
            {:ok, %Fedi.Streams.MappedNameProp{mapped: Enum.reverse(mapped), unmapped: unmapped}}
        end
    end
  end

  def serialize(%{member: member}) when is_struct(member) do
    apply(member.__struct__, :serialize, [member])
  end

  def serialize(%{rdf_lang_string_member: v}) when is_map(v) do
    Fedi.Streams.Literal.LangString.serialize(v)
  end

  def serialize(%{xml_schema_date_time_member: %DateTime{} = v}) do
    Fedi.Streams.Literal.DateTime.serialize(v)
  end

  def serialize(%{xml_schema_duration_member: %Timex.Duration{} = v}) do
    Fedi.Streams.Literal.Duration.serialize(v)
  end

  def serialize(%{xml_schema_non_neg_integer_member: v}) when is_integer(v) do
    Fedi.Streams.Literal.NonNegInteger.serialize(v)
  end

  def serialize(%{xml_schema_float_member: v}) when is_float(v) do
    Fedi.Streams.Literal.Float.serialize(v)
  end

  def serialize(%{xml_schema_string_member: str}) when is_binary(str) do
    {:ok, str}
  end

  def serialize(%{xml_schema_any_uri_member: %URI{} = uri}) do
    Fedi.Streams.Literal.AnyURI.serialize(uri)
  end

  def serialize(%{iri: %URI{} = iri}) do
    {:ok, URI.to_string(iri)}
  end

  def serialize(%{unknown: unknown}) do
    {:ok, unknown}
  end

  #### Getters

  # get returns the value of this property
  def get(%{member: value}) when is_struct(value), do: value
  def get(_), do: nil

  # get_iri returns the IRI of this property. When is_iri returns false,
  # get_iri will return any arbitrary value.
  def get_iri(%{iri: %URI{} = v}), do: v
  def get_iri(_), do: nil

  # get_xml_schema_any_uri returns the value of this property. When IsXMLSchemaAnyURI
  # returns false, get_xml_schema_any_uri will return an arbitrary value.
  def get_xml_schema_any_uri(%{xml_schema_any_uri_member: %URI{} = v}), do: v
  def get_xml_schema_any_uri(_), do: nil

  # get_xml_schema_string returns the value of this property. When is_xml_schema_string
  # returns false, get_xml_schema_string will return an arbitrary value.
  def get_xml_schema_string(%{xml_schema_string_member: v}) when is_binary(v), do: v
  def get_xml_schema_string(_), do: nil

  # json_ld_context returns the JSONLD URIs required in the context string
  # for this property and the specific values that are set. The value
  # in the map is the alias used to import the property's value or
  # values.
  # TODO
  def json_ld_context(_prop) do
    %{}
  end

  #### Queries

  # is_iri returns true if this property is an IRI.
  def is_iri(%{iri: %URI{}}), do: true
  def is_iri(_), do: false

  # is_xml_schema_any_uri returns true if this property is set and not an IRI.
  def is_xml_schema_any_uri(%{xml_schema_any_uri_member: %URI{}}), do: true
  def is_xml_schema_any_uri(_), do: false

  # is_xml_schema_string returns true if this property has a type of "string". When
  # true, use the get_xml_schema_string and set_xml_schema_string methods to access
  # and set this property.
  def is_xml_schema_string(%{xml_schema_string_member: v}) when is_binary(v), do: true
  def is_xml_schema_string(_), do: false

  #### Setters

  # set sets the value of this property. Calling is_xml_schema_any_uri
  # afterwards will return true.
  def set(%{__struct__: module, member: _old_value} = prop, v) when is_struct(v) do
    apply(module, :clear, [prop])
    |> struct(member: v)
  end

  # set_iri sets the value of this property. Calling is_iri afterwards will
  # return true.
  def set_iri(%{__struct__: module, iri: _old_value} = prop, %URI{} = v) do
    apply(module, :clear, [prop])
    |> struct(iri: v)
  end

  # set_xml_schema_any_uri sets a new IRI value.
  def set_xml_schema_any_uri(
        %{__struct__: module, xml_schema_any_uri_member: _old_value} = prop,
        %URI{} = v
      ) do
    apply(module, :clear, [prop])
    |> struct(xml_schema_any_uri_member: v)
  end

  # set_xml_schema_string sets a new IRI value.
  def set_xml_schema_string(
        %{
          __struct__: module,
          xml_schema_string_member: _old_string,
          has_string_member: _old_has
        } = prop,
        v
      )
      when is_binary(v) do
    apply(module, :clear, [prop])
    |> struct(xml_schema_string_member: v, has_string_member: true)
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
      {{_prop_name, _prop_mod}, idx} -> idx + 1
      nil -> base_kind_index(prop)
    end
  end

  def kind_index(prop, _), do: base_kind_index(prop)

  def base_kind_index(%{xml_schema_any_uri_member: %URI{}}), do: 0
  def base_kind_index(%{iri: %URI{}}), do: -2
  def base_kind_index(_), do: -1

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
        val1 = get(prop)
        val2 = get(o)
        apply(val1.__struct__, :less_than, [val1, val2])

      true ->
        nil
    end
    |> case do
      is_less_than when is_boolean(is_less_than) ->
        is_less_than

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

  #### Utility functions

  def get_prop(m, prop_names, alias_) when is_binary(alias_) do
    prop_names
    |> List.wrap()
    |> Enum.reduce_while(nil, fn prop_name, _acc ->
      prop_name =
        case alias_ do
          "" ->
            prop_name

          _ ->
            alias_ <> ":" <> prop_name
        end

      case Map.get(m, prop_name) do
        nil ->
          {:cont, nil}

        val ->
          # TODO use predicate function
          mapped_property? = String.ends_with?(prop_name, "Map")
          {:halt, {val, prop_name, mapped_property?}}
      end
    end)
  end

  def get_values(m, prop_names, alias_) when is_binary(alias_) do
    prop_names
    |> List.wrap()
    |> Enum.reduce([], fn prop_name, acc ->
      prop_name =
        case alias_ do
          "" ->
            prop_name

          _ ->
            alias_ <> ":" <> prop_name
        end

      case Map.get(m, prop_name) do
        nil ->
          acc

        val ->
          # TODO use predicate function
          mapped_property? = String.ends_with?(prop_name, "Map")
          [{val, prop_name, mapped_property?} | acc]
      end
    end)
  end

  def name(prop_names, alias_, is_map \\ false) do
    prop_name =
      prop_names
      |> List.wrap()
      |> List.first()

    map_suffix = if is_map, do: "Map", else: ""

    case alias_ do
      "" -> prop_name <> map_suffix
      _ -> alias_ <> ":" <> prop_name <> map_suffix
    end
  end

  def maybe_iri(i) do
    case Fedi.Streams.Literal.String.maybe_to_string(i) do
      {:ok, s} ->
        uri = URI.parse(s)

        # If error exists, don't error out -- skip this and treat as unknown string ([]byte) at worst
        # Also, if no scheme exists, don't treat it as a URL -- net/url is greedy
        if !is_nil(uri.scheme) do
          {:ok, uri}
        else
          :error
        end

      _ ->
        :error
    end
  end
end
