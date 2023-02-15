defmodule Fedi.Streams.Literal.Float do
  @moduledoc false

  @doc """
  Converts a float value to an interface representation suitable
  for marshalling into a text or binary format.
  """
  def serialize(this) when is_float(this), do: {:ok, this}

  @doc """
  Creates a float value from an interface representation that
  has been unmarshalled from a text or binary format.
  """
  def deserialize(v) when is_float(v), do: {:ok, v}

  def deserialize(v) when is_binary(v) do
    case Float.parse(v) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, "#{v} cannot be parsed as an xsd::float"}
    end
  end

  def deserialize(v), do: {:error, "#{inspect(v)} cannot be parsed as an xsd::float"}

  @doc """
  Returns true if the left float value is less than the right value.
  """
  def less(lhs, rhs) when is_float(lhs) and is_float(rhs) do
    lhs < rhs
  end
end
