defmodule Fedi.Streams.BaseType do
  @moduledoc false

  require Logger

  def get_type_name(%{__struct__: module}) do
    Module.concat([module, Meta])
    |> apply(:type_name, [])
  end

  def disjoint_with(%{__struct__: module}, other) when is_struct(other) do
    other_type_name = get_type_name(other)

    Module.concat([module, Meta])
    |> apply(:disjoint_with, [])
    |> Enum.member?(other_type_name)
  end

  def is_extended_by(%{__struct__: module}, other) when is_struct(other) do
    other_type_name = get_type_name(other)

    Module.concat([module, Meta])
    |> apply(:extended_by, [])
    |> Enum.member?(other_type_name)
  end

  def extends(%{__struct__: module}, other) when is_struct(other) do
    other_type_name = get_type_name(other)

    Module.concat([module, Meta])
    |> apply(:extends, [])
    |> Enum.member?(other_type_name)
  end

  def is_or_extends(%{__struct__: module}, other) when is_struct(other) do
    other_type_name = get_type_name(other)
    module = Module.concat([module, Meta])

    if apply(module, :type_name, []) == other_type_name do
      true
    else
      apply(module, :extends, [])
      |> Enum.member?(other_type_name)
    end
  end

  def deserialize(namespace, module, m, alias_map) when is_map(m) and is_map(alias_map) do
    {alias_, alias_prefix} =
      case Fedi.Streams.get_alias(alias_map, namespace) do
        "" -> {"", ""}
        a -> {a, a <> ":"}
      end

    type_name = Module.concat([module, Meta]) |> apply(:type_name, [])

    case find_type(m, alias_prefix, type_name) do
      {:error, reason} ->
        {:error, reason}

      :ok ->
        # Begin: Known property deserialization
        known_properties = Fedi.Streams.properties(namespace)

        known_prop_map =
          known_properties
          |> Enum.reduce_while(%{}, fn {prop_name, prop_mod}, acc ->
            case apply(prop_mod, :deserialize, [m, alias_map]) do
              {:error, reason} ->
                {:halt, {:error, reason}}

              {:ok, nil} ->
                {:cont, acc}

              {:ok, v} ->
                Logger.error("adding known #{prop_name}")
                {:cont, Map.put(acc, prop_name, v)}
            end
          end)

        # End: Known property deserialization
        case known_prop_map do
          {:error, reason} ->
            {:error, reason}

          _ ->
            known_property_names = Enum.map(known_properties, fn {prop_name, _} -> prop_name end)
            Logger.error("checking unknown props in #{Map.keys(m) |> Enum.join(" ")}")
            # Begin: Unknown deserialization
            # Begin: Code that ensures a property name is unknown
            unknown =
              Enum.reduce(m, %{}, fn {prop_name, v}, acc ->
                if Enum.member?(known_property_names, prop_name) do
                  acc
                else
                  Logger.error("adding unknown #{prop_name}")
                  Map.put(acc, prop_name, v)
                end
              end)

            # End: Code that ensures a property name is unknown
            # End: Unknown deserialization
            Logger.error("deserialized #{module}")
            {:ok, struct(module, alias: alias_, properties: known_prop_map, unknown: unknown)}
        end
    end
  end

  def serialize(%{__struct__: module, alias: alias_, properties: properties, unknown: unknown}) do
    type_name = Module.concat([module, Meta]) |> apply(:type_name, [])

    type_name =
      case alias_ do
        "" -> type_name
        _ -> alias_ <> ":" <> type_name
      end

    # Begin: Serialize known properties

    m = %{"type" => type_name}

    properties
    |> Enum.reduce_while(
      m,
      fn {prop_name, %{__struct__: prop_mod} = prop_value}, acc ->
        case apply(prop_mod, :serialize, [prop_value]) do
          {:error, reason} ->
            {:halt, {:error, reason}}

          {:ok, nil} ->
            {:cont, acc}

          {:ok, %Fedi.Streams.MappedNameProp{mapped: mapped, unmapped: unmapped}} ->
            acc =
              case mapped do
                nil -> acc
                [] -> acc
                _ -> Map.put(acc, prop_name <> "Map", mapped)
              end

            acc =
              case unmapped do
                nil -> acc
                [] -> acc
                _ -> Map.put(acc, prop_name, unmapped)
              end

            {:cont, acc}

          {:ok, v} ->
            {:cont, Map.put(acc, prop_name, v)}
        end
      end
    )
    |> case do
      # End: Serialize known properties
      {:error, reason} ->
        {:error, reason}

      m ->
        # Begin: Serialize unknown properties, like "@context"
        m =
          Enum.reduce(unknown, m, fn {k, v}, acc ->
            Map.put_new(acc, k, v)
          end)

        # End: Serialize unknown properties

        {:ok, m}
    end
  end

  def find_type(%{"type" => type_value}, alias_prefix, type_name) do
    type_value
    |> List.wrap()
    |> Enum.find(fn elem_val ->
      case Fedi.Streams.Literal.String.maybe_to_string(elem_val) do
        {:ok, type_string} ->
          if alias_prefix == "" do
            type_name == type_string
          else
            type_name == String.replace_leading(type_string, alias_prefix, "")
          end

        _ ->
          Logger.error("Could not coerce #{inspect(elem_val)} into a string")
          false
      end
    end)
    |> case do
      nil -> {:error, "Could not find a \"type\" property of value \"#{type_name}\""}
      _ -> :ok
    end
  end

  def find_type(m, _alias_prefix, _type_name) do
    Logger.error("Could not find a \"type\" property in map #{inspect(m)}")
    {:error, "Could not find a \"type\" property in map"}
  end
end
