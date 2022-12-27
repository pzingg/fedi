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

  def deserialize_properties(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    iterator_module =
      Module.split(module)
      |> List.update_at(-1, fn name -> name <> "Iterator" end)
      |> Module.concat()

    case get_props(m, prop_name, alias_) do
      [] ->
        {:ok, nil}

      props ->
        result =
          props
          |> Enum.reduce_while({[], []}, fn {i, prop_name, map_prop}, {map_acc, acc} ->
            case apply(iterator_module, :deserialize, [i, alias_map]) do
              {:ok, value} ->
                if map_prop do
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

          {mapped_properties, properties} ->
            mapped_properties = Enum.reverse(mapped_properties)
            properties = Enum.reverse(properties)

            if Enum.empty?(mapped_properties) do
              {:ok, struct(module, alias: alias_, properties: properties)}
            else
              {:ok,
               struct(module,
                 alias: alias_,
                 mapped_properties: mapped_properties,
                 properties: properties
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
  def serialize_properties(prop) do
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

  def serialize_mapped_properties(prop) do
    case serialize_properties(prop) do
      {:error, reason} ->
        {:error, reason}

      {:ok, unmapped} ->
        result =
          Enum.reduce_while(prop.mapped_properties, [], fn it, acc ->
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

  #### Other common functions

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
          map_property = String.ends_with?(prop_name, "Map")
          {:halt, {val, prop_name, map_property}}
      end
    end)
  end

  def get_props(m, prop_names, alias_) when is_binary(alias_) do
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
          map_property = String.ends_with?(prop_name, "Map")
          [{val, prop_name, map_property} | acc]
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
