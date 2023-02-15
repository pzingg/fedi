defmodule Fedi.Streams.Literal.DateTime do
  @moduledoc false

  @doc """
  Converts a `DateTime` value to an interface representation suitable
  for marshalling into a text or binary format.
  """
  def serialize(%DateTime{} = this), do: {:ok, this}

  @doc """
  Creates a `DateTime` value from an interface representation that
  has been unmarshalled from a text or binary format.
  """
  def deserialize(%DateTime{} = v), do: {:ok, v}

  def deserialize(v) when is_binary(v) do
    case DateTime.from_iso8601(v) do
      {:ok, parsed, _tz} -> {:ok, parsed}
      _ -> {:error, "#{v} cannot be parsed as an xsd:dateTime"}
    end
  end

  def deserialize(v), do: {:error, "#{inspect(v)} cannot be parsed as an xsd:dateTime"}

  @doc """
  Returns true if the left `DateTime` value is less than the right value.
  """
  def less(%DateTime{} = lhs, %DateTime{} = rhs) do
    lhs < rhs
  end
end
