defmodule Fedi.Streams.Serializer do
  @moduledoc false

  require Logger

  def serialize(%{__struct__: module} = object) do
    try do
      module = Code.ensure_compiled!(module)
      result = apply(module, :serialize, [object])
      # Logger.error("serialized: #{inspect(result)}")
      result
    rescue
      e ->
        {:error, "Serializer exception: #{inspect(e)}"}
    end
  end

  def serialize(object) do
    {:error, "Cannot serialize non-struct #{inspect(object)}"}
  end
end
