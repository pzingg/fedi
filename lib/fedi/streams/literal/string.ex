defmodule Fedi.Streams.Literal.String do
  @moduledoc false

  def maybe_to_string(v) when is_list(v) or is_map(v),
    do: {:error, "#{inspect(v)} cannot be interpreted as a string for xsd:string"}

  def maybe_to_string(v) do
    try do
      {:ok, to_string(v)}
    rescue
      _ ->
        {:error, "#{inspect(v)} cannot be interpreted as a string for xsd:string"}
    end
  end

  # serialize converts a string value to an interface representation suitable
  # for marshalling into a text or binary format.
  def serialize(this) when is_binary(this), do: {:ok, this}

  # deserialize creates string value from an interface representation that
  # has been unmarshalled from a text or binary format.
  def deserialize(v) do
    maybe_to_string(v)
  end

  # less returns true if the left string value is less than the right value.
  def less(lhs, rhs) when is_binary(lhs) and is_binary(rhs) do
    lhs < rhs
  end
end
