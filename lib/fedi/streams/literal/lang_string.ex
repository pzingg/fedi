defmodule Fedi.Streams.Literal.LangString do
  @moduledoc false

  def maybe_to_string(v) when is_list(v) or is_map(v) do
    {:error, "#{inspect(v)} cannot be interpreted as a string for rdf:langString"}
  end

  def maybe_to_string(v) do
    try do
      {:ok, to_string(v)}
    rescue
      _ ->
        {:error, "#{inspect(v)} cannot be interpreted as a string for rdf:langString"}
    end
  end

  # serialize converts a string value to an interface representation suitable
  # for marshalling into a text or binary format.
  def serialize(this) when is_map(this), do: {:ok, this}

  # deserialize creates string value from an interface representation that
  # has been unmarshalled from a text or binary format.
  def deserialize(v) when is_map(v) do
    Enum.reduce_while(v, Map.new(), fn {k, v}, acc ->
      case maybe_to_string(v) do
        {:ok, s} ->
          {:cont, Map.put(acc, k, s)}

        _ ->
          {:halt, {:error, "#{inspect(v)} cannot be interpreted as a string for rdf:langString"}}
      end
    end)
    |> case do
      m when is_map(m) -> {:ok, m}
      {:error, reason} -> {:error, reason}
    end
  end

  def deserialize(v) do
    {:error, "#{inspect(v)} cannot be interpreted as a map for rdf:langString"}
  end

  # less returns true if the left string value is less than the right value.
  def less(lhs, rhs) when is_map(lhs) and is_map(rhs) do
    lk = Map.keys(lhs) |> Enum.sort()
    rk = Map.keys(rhs) |> Enum.sort()
    llen = Enum.count(lk)
    rlen = Enum.count(rk)
    last = min(llen, rlen) - 1

    Enum.reduce_while(0..last, nil, fn i, acc ->
      l = Enum.at(lk, i)
      r = Enum.at(rk, i)

      cond do
        l < r -> {:halt, true}
        r < l -> {:halt, false}
        lhs[l] < rhs[r] -> {:halt, true}
        rhs[l] < lhs[r] -> {:halt, false}
        true -> {:cont, acc}
      end
    end)
    |> case do
      true -> true
      false -> false
      nil -> llen < rlen
    end
  end
end
