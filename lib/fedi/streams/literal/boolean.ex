defmodule Fedi.Streams.Literal.Boolean do
  @moduledoc false

  @doc """
  Converts a boolean value to an interface representation suitable
  for marshalling into a text or binary format.
  """
  def serialize(this) when is_boolean(this), do: {:ok, this}

  @doc """
  Creates a boolean value from an interface representation that
  has been unmarshalled from a text or binary format.
  """
  def deserialize(v) when is_boolean(v), do: {:ok, v}

  def deserialize(v) when is_number(v) do
    case v do
      0 -> {:ok, false}
      1 -> {:ok, true}
      _ -> {:error, "#{v} cannot be interpreted as an xsd:boolean"}
    end
  end

  def deserialize(v), do: {:error, "#{inspect(v)} cannot be interpreted as an xsd:boolean"}

  @doc """
  Returns true if the left boolean value is less than the right value.
  """
  def less(lhs, rhs) when is_boolean(lhs) and is_boolean(rhs) do
    !lhs && rhs
  end
end
