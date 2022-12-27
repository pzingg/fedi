defmodule Fedi.Streams.BaseProperty do
  @moduledoc false

  require Logger

  def deserialize(namespace, module, prop_name, m, alias_map, types \\ nil)

  def deserialize(namespace, module, prop_name, m, alias_map, types) do
    al = Fedi.Streams.get_alias(alias_map, namespace)

    prop_name =
      case al do
        "" -> prop_name
        _ -> al <> ":" <> prop_name
      end

    case Map.get(m, prop_name) do
      nil ->
        {:ok, nil}

      i ->
        deserialize_with_alias(al, module, i, alias_map, types)
    end
  end

  def deserialize_properties(namespace, module, prop_name, m, alias_map)
      when is_map(m) and is_map(alias_map) do
    alias = Fedi.Streams.get_alias(alias_map, namespace)

    iterator_module =
      Module.split(module)
      |> List.update_at(-1, fn name -> name <> "Iterator" end)
      |> Module.concat()

    # Logger.error("iterator module #{inspect(iterator_module)}")

    prop_name =
      case alias do
        "" -> prop_name
        _ -> alias <> ":" <> prop_name
      end

    case Map.get(m, prop_name) do
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
          {:ok, props} -> {:ok, struct(module, alias: alias, properties: Enum.reverse(props))}
          error -> error
        end
    end
  end

  def deserialize_with_alias(al, module, i, alias_map, types) do
    case maybe_iri(i) do
      {:ok, uri} ->
        {:ok, struct(module, alias: al, iri: uri)}

      _ ->
        deserialize_types(al, module, i, alias_map, types)
    end
    |> case do
      {:ok, this} -> {:ok, this}
      _ -> {:ok, struct(module, alias: al, unknown: i)}
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

  def deserialize_types(al, module, i, alias_map, types \\ nil)

  def deserialize_types(al, module, i, alias_map, types) when is_map(i) do
    (types || Fedi.Streams.all_type_modules())
    |> Enum.reduce_while(:error, fn type_mod, acc ->
      case apply(type_mod, :deserialize, [i, alias_map]) do
        {:ok, v} when is_struct(v) ->
          {:halt, {:ok, struct(module, alias: al, member: v)}}

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
