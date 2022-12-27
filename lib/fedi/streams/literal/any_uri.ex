defmodule Fedi.Streams.Literal.AnyURI do
  @moduledoc false

  # serialize converts a anyURI value to an interface representation suitable
  # for marshalling into a text or binary format.
  def serialize(%URI{} = uri) do
    {:ok, URI.to_string(uri)}
  end

  # deserialize creates anyURI value from an interface representation that
  # has been unmarshalled from a text or binary format.
  def deserialize(v) do
    case Fedi.Streams.Literal.String.maybe_to_string(v) do
      {:ok, s} ->
        uri = URI.parse(s)

        if is_nil(uri.scheme) do
          {:error, "#{s} cannot be interpreted as a xsd:anyURI: no scheme"}
        else
          {:ok, uri}
        end

      error ->
        error
    end
  end

  # less returns true if the left anyURI value is less than the right value.
  def less(lhs, %URI{} = rhs) do
    case Fedi.Streams.Literal.String.maybe_to_string(lhs) do
      {:ok, s} -> s < URI.to_string(rhs)
      _ -> false
    end
  end
end
