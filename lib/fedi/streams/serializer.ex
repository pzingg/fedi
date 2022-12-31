defmodule Fedi.Streams.Serializer do
  @moduledoc false

  def serialize(%{__struct__: module} = object) do
    try do
      module = Code.ensure_compiled!(module)
      apply(module, :serialize, [object])
    rescue
      e ->
        {:error, "Serializer exception: #{inspect(e)}"}
    end
  end

  def serialize(_object) do
    {:error, "Object is not a struct"}
  end
end
