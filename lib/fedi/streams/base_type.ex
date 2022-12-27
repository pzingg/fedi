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
    {alias, alias_prefix} =
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
              {:error, reason} -> {:halt, {:error, reason}}
              {:ok, nil} -> {:cont, acc}
              {:ok, v} -> {:cont, Map.put(acc, prop_name, v)}
            end
          end)

        # End: Known property deserialization
        case known_prop_map do
          {:error, reason} ->
            {:error, reason}

          _ ->
            known_property_names = Enum.map(known_properties, fn {prop_name, _} -> prop_name end)

            # Begin: Unknown deserialization
            # Begin: Code that ensures a property name is unknown
            unknown =
              Enum.reduce(m, %{}, fn {prop_name, v}, acc ->
                if Enum.member?(known_property_names, prop_name) do
                  acc
                else
                  Map.put(acc, prop_name, v)
                end
              end)

            # End: Code that ensures a property name is unknown
            # End: Unknown deserialization
            {:ok, struct(module, alias: alias, properties: known_prop_map, unknown: unknown)}
        end
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
    Logger.error("find_type no \"type\" property in map #{inspect(m)}")
    {:error, "no \"type\" property in map"}
  end
end
