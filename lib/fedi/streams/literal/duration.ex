defmodule Fedi.Streams.Literal.Duration do
  @moduledoc false

  # serialize converts a float value to an interface representation suitable
  # for marshalling into a text or binary format.
  def serialize(%Timex.Duration{} = this), do: {:ok, this}

  # deserialize creates float value from an interface representation that
  # has been unmarshalled from a text or binary format.
  def deserialize(%Timex.Duration{} = v), do: {:ok, v}

  def deserialize(v) when is_binary(v) do
    case Timex.Parse.Duration.Parsers.ISO8601Parser.parse(v) do
      {:ok, parsed} -> {:ok, parsed}
      _ -> {:error, "#{v} cannot be parsed as an xsd:duration"}
    end
  end

  def deserialize(v), do: {:error, "#{inspect(v)} cannot be parsed as an xsd:duration"}

  # less returns true if the left value is less than the right value.
  def less(%Timex.Duration{} = lhs, %Timex.Duration{} = rhs) do
    lhs < rhs
  end
end
