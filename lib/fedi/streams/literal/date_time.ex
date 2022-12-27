defmodule Fedi.Streams.Literal.DateTime do
  @moduledoc false

  # serialize converts a float value to an interface representation suitable
  # for marshalling into a text or binary format.
  def serialize(%DateTime{} = this), do: {:ok, this}

  # deserialize creates float value from an interface representation that
  # has been unmarshalled from a text or binary format.
  def deserialize(%DateTime{} = v), do: {:ok, v}

  def deserialize(v) when is_binary(v) do
    case DateTime.from_iso8601(v) do
      {:ok, parsed, _tz} -> {:ok, parsed}
      _ -> {:error, "#{v} cannot be parsed as an xsd:dateTime"}
    end
  end

  def deserialize(v), do: {:error, "#{inspect(v)} cannot be parsed as an xsd:dateTime"}

  # less returns true if the left value is less than the right value.
  def less(%DateTime{} = lhs, %DateTime{} = rhs) do
    lhs < rhs
  end
end
