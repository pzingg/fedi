defmodule Fedi.Streams.Serializer do
  @moduledoc false

  def serialize(object) when is_struct(object) do
    try do
      apply(object.__struct__, :serialize, [object])
    rescue
      _e ->
        {:error, "Undefined: #{object.__struct__}.serialize/1"}
    end
  end

  def serialize(_object) do
    {:error, "Object is not a struct"}
  end
end
