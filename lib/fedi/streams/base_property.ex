defmodule Fedi.Streams.BaseProperty do
  @moduledoc false

  require Logger

  def deserialize(namespace, module, prop_name, m, alias_map, types \\ nil)

  def deserialize(namespace, module, prop_name, m, alias_map, types) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    case Fedi.Streams.BaseProperty.get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      i ->
        deserialize_with_alias(alias_, module, i, alias_map, types)
    end
  end

  def deserialize_properties(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias_ = Fedi.Streams.get_alias(alias_map, namespace)

    iterator_module =
      Module.split(module)
      |> List.update_at(-1, fn name -> name <> "Iterator" end)
      |> Module.concat()

    # Logger.error("iterator module #{inspect(iterator_module)}")

    case get_prop(m, prop_name, alias_) do
      nil ->
        {:ok, nil}

      i ->
        properties =
          List.wrap(i)
          |> Enum.reduce_while({:ok, []}, fn prop, {:ok, acc} ->
            case apply(iterator_module, :deserialize, [prop, alias_map]) do
              {:ok, value} ->
                {:cont, {:ok, [value | acc]}}

              {:error, reason} ->
                Logger.error("iterating #{prop_name}, got error #{reason}")
                {:halt, {:error, reason}}
            end
          end)

        case properties do
          {:ok, props} -> {:ok, struct(module, alias: alias_, properties: Enum.reverse(props))}
          error -> error
        end
    end
  end

  def get_prop(m, prop_names, alias_) do
    prop_names
    |> List.wrap()
    |> Enum.reduce_while(nil, fn prop_name, _acc ->
      prop_name =
        case alias_ do
          "" -> prop_name
          _ -> alias_ <> ":" <> prop_name
        end

      case Map.get(m, prop_name) do
        nil -> {:cont, nil}
        val -> {:halt, val}
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

  def deserialize_types(alias_, module, i, alias_map, types \\ nil)

  def deserialize_types(alias_, module, i, alias_map, types) when is_map(i) do
    (types || Fedi.Streams.all_type_modules())
    |> Enum.reduce_while(:error, fn type_mod, acc ->
      case apply(type_mod, :deserialize, [i, alias_map]) do
        {:ok, v} when is_struct(v) ->
          {:halt, {:ok, struct(module, alias: alias_, member: v)}}

        {:ok, v} ->
          Logger.error("deserialize_types didn't return a struct: #{inspect(v)}")
          {:cont, acc}

        _ ->
          {:cont, acc}
      end
    end)
  end

  def deserialize_types(_, _, _, _, _), do: :error
end
