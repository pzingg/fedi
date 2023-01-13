defmodule Fedi.Streams.JSONResolver do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Utils

  @doc """
  Determines the ActivityStreams type of the payload, then applies the
  first callback function whose signature accepts the ActivityStreams value's
  type. This strictly assures that the callback function will only be passed
  ActivityStream objects whose type matches its interface. Returns an error
  if the ActivityStreams type does not match callbackers or is not a type
  handled by the generated code. If multiple types are present, it will check
  each one in order and apply only the first one. It returns an unhandled
  error for a multi-typed object if none of the types were able to be handled.
  """
  def resolve(msg) when is_binary(msg) do
    with {:ok, m} <- Jason.decode(msg) do
      resolve(m)
    end
  end

  def resolve(m) when is_map(m) do
    case get_type_and_context(m) do
      {:error, reason} ->
        {:error, reason}

      {:ok,
       %{
         alias_map: alias_map,
         type: _type_value,
         activity_streams: _activity_streams_prefix,
         security_v1: _security_v1_prefix,
         mastodon: _mastodon_prefix
       }} ->
        Fedi.Streams.type_modules(:activity_streams)
        |> Enum.reduce_while({m, alias_map}, fn type_module, {acc_m, acc_alias_map} ->
          case apply(type_module, :deserialize, [acc_m, acc_alias_map]) do
            {:ok, val} -> {:halt, {:ok, val}}
            {:error, _} -> {:cont, {acc_m, acc_alias_map}}
          end
        end)
    end
  end

  def resolve_with_as_context(m) when is_map(m) do
    Map.put(m, "@context", "https://www.w3.org/ns/activitystreams")
    |> resolve()
  end

  def get_type_and_context(m) do
    with {:type, type_value} when is_binary(type_value) <- {:type, m["type"]},
         {:context, raw_context} when not is_nil(raw_context) <- {:context, m["@context"]} do
      alias_map = List.wrap(raw_context) |> to_alias_map()

      {:ok,
       %{
         alias_map: alias_map,
         type: type_value,
         activity_streams: alias_prefix(alias_map, "www.w3.org/ns/activitystreams"),
         security_v1: alias_prefix(alias_map, "w3id.org/security/v1"),
         mastodon: alias_prefix(alias_map, "joinmastodon.org/ns")
       }}
    else
      {:type, _} ->
        {:error,
         Utils.err_unhandled_type(
           "Cannot determine ActivityStreams type: 'type' property is missing",
           json: m
         )}

      {:context, _} ->
        {:error,
         Utils.err_unhandled_type("Cannot determine ActivityStreams type: '@context' is missing",
           json: m
         )}
    end
  end

  def alias_prefix(alias_map, host_and_path)
      when is_map(alias_map) and is_binary(host_and_path) do
    case Map.get(alias_map, "http://" <> host_and_path, "") do
      "" ->
        case Map.get(alias_map, "https://" <> host_and_path, "") do
          "" -> ""
          prefix -> prefix <> ":"
        end

      prefix ->
        prefix <> ":"
    end
  end

  @doc """
  to_alias_map converts a JSONLD context into a map of vocabulary name to alias.
  """
  def to_alias_map(i) when is_list(i) do
    # Recursively apply.
    alias_map_elem(i, []) |> Map.new()
  end

  def alias_map_elem(i, acc) when is_list(i) or is_map(i) do
    Enum.reduce(i, acc, fn v, acc1 -> alias_map_elem(v, acc1) end)
  end

  def alias_map_elem(i, acc) when is_binary(i) do
    # Single entry, no alias.
    case http_and_https(i) do
      {:ok, http, https} ->
        [{http, ""} | [{https, ""} | acc]]

      _ ->
        [{i, ""} | acc]
    end
  end

  def alias_map_elem({k, v}, acc) do
    [{k, v} | acc]
  end

  def alias_map_elem(other, acc) do
    Logger.error("Can't understand @context element #{inspect(other)}")
    acc
  end

  def http_and_https(str) do
    cond do
      String.starts_with?(str, "http:") ->
        {:ok, str, String.replace_leading(str, "http:", "https:")}

      String.starts_with?(str, "https:") ->
        {:ok, String.replace_leading(str, "https:", "http:"), str}

      true ->
        {:error, "Not an http or https URI"}
    end
  end
end
