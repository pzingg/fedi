defmodule Fedi.Streams.BaseType do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Utils

  def get_type_name(%{__struct__: module}, opts \\ []) do
    type_name = apply(module, :type_name, [])

    type_name =
      cond do
        Keyword.get(opts, :atom, false) ->
          type_name |> Macro.underscore() |> String.to_atom()

        Keyword.get(opts, :snake_case, false) ->
          type_name |> Macro.underscore()

        true ->
          type_name
      end

    if Keyword.get(opts, :with_namespace, false) do
      {type_name, apply(module, :namespace, [])}
    else
      type_name
    end
  end

  def disjoint_with?(%{__struct__: module}, other) when is_struct(other) do
    other_type_name = get_type_name(other)

    apply(module, :disjoint_with?, [other_type_name])
  end

  def extended_by?(%{__struct__: module}, other) when is_struct(other) do
    other_type_name = get_type_name(other)

    apply(module, :extended_by, [])
    |> Enum.member?(other_type_name)
  end

  def is_or_extends?(%{__struct__: module}, other) when is_struct(other) do
    other_type_name = get_type_name(other)
    apply(module, :is_or_extends?, [other_type_name])
  end

  def resolve(m, types, context) do
    types
    |> Enum.reduce_while(m, fn type, acc ->
      case reduce_type(context, type, acc) do
        {:ok, val} -> {:halt, {:ok, val}}
        _ -> {:cont, acc}
      end
    end)
    |> case do
      {:ok, val} ->
        {:ok, val}

      _ ->
        {:error, "Unhandled #{inspect(types)}"}
    end
  end

  def reduce_type(_context, "", m) do
    {:cont, m}
  end

  def reduce_type(%{alias_map: _alias_map} = context, type, m) when is_binary(type) do
    [:activity_streams, :w3_id_security_v1, :toot]
    |> Enum.reduce_while(m, fn namespace, acc ->
      {vocab_module, alias_prefix} = Map.fetch!(context, namespace)

      with raw_type when not is_nil(raw_type) <-
             get_raw_type(type, alias_prefix),
           type_module when not is_nil(type_module) <-
             vocab_module.get_type_module(raw_type),
           {:ok, val} <-
             deserialize(namespace, type_module, m, context) do
        {:halt, {:ok, val}}
      else
        _ -> {:cont, acc}
      end
    end)
  end

  def reduce_type(_context, _type, m) do
    {:cont, m}
  end

  def get_raw_type("", _), do: nil

  def get_raw_type(type, ""), do: type

  def get_raw_type(type, alias_prefix) do
    if String.starts_with?(type, alias_prefix) do
      String.replace_leading(type, alias_prefix, "")
    else
      nil
    end
  end

  def deserialize(namespace, module, m, context) when is_map(m) do
    # Begin: Known property deserialization
    known_properties = Fedi.Streams.properties(namespace)

    known_prop_map =
      known_properties
      |> Enum.reduce_while(%{}, fn {prop_name, prop_mod}, acc ->
        case apply(prop_mod, :deserialize, [m, context]) do
          {:error, reason} ->
            Logger.error("Error adding known #{prop_name}: #{reason}")
            {:halt, {:error, reason}}

          {:ok, nil} ->
            {:cont, acc}

          {:ok, v} ->
            {:cont, Map.put(acc, prop_name, v)}
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

        {_vocab_module, alias_} = Map.fetch!(context, namespace)
        value = struct(module, alias: alias_, properties: known_prop_map, unknown: unknown)
        {:ok, value}
    end
  end

  def serialize(%{__struct__: module, alias: alias_, properties: properties, unknown: unknown}) do
    type_name = apply(module, :type_name, [])

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

          {:ok, %Fedi.Streams.MappedNameProp{unmapped: unmapped, mapped: mapped}} ->
            acc =
              case unmapped do
                nil -> acc
                _ -> Map.put(acc, prop_name, unmapped)
              end

            acc =
              case mapped do
                nil -> acc
                _ -> Map.put(acc, prop_name <> "Map", mapped)
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
          case unknown do
            nil ->
              m

            unk when is_map(unk) ->
              Enum.reduce(unknown, m, fn {k, v}, acc ->
                Map.put_new(acc, k, v)
              end)

            _ ->
              Logger.error("#{type_name}.unknown is not a map: #{inspect(unknown)}")
              m
          end

        # End: Serialize unknown properties

        {:ok, m}
    end
  end

  def serialize(%{__struct__: module, alias: _} = _object) do
    Logger.error("Error serializing #{Utils.alias_module(module)} without properties")
    {:error, "Object #{Utils.alias_module(module)} must have properties"}
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
