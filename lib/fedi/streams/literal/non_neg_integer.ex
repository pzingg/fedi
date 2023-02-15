defmodule Fedi.Streams.Literal.NonNegInteger do
  @moduledoc false

  @doc """
  Converts a non-negative integer value to an interface representation suitable
  for marshalling into a text or binary format.
  """
  def serialize(this) when is_integer(this) and this >= 0, do: {:ok, this}

  @doc """
  Creates a non-negative integer value from an interface representation that
  has been unmarshalled from a text or binary format.
  """
  def deserialize(v) when is_integer(v), do: {:ok, v}

  def deserialize(v) when is_binary(v) do
    case Integer.parse(v) do
      {parsed, ""} when parsed >= 0 -> {:ok, parsed}
      {parsed, ""} -> {:error, "#{parsed} is less than zero"}
      _ -> {:error, "#{v} cannot be parsed as a non-negative integer"}
    end
  end

  def deserialize(v), do: {:error, "#{inspect(v)} cannot be parsed as a non-negative integer"}

  @doc """
  Returns true if the left non-negative integer value is less than the right value.
  """
  def less(lhs, rhs) when is_integer(lhs) and is_integer(rhs) do
    lhs < rhs
  end
end
