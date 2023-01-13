defmodule Fedi.Streams.Serializer do
  @moduledoc false

  require Logger

  def serialize(%{__struct__: module} = object) do
    try do
      Code.ensure_compiled!(module)
      |> apply(:serialize, [object])
    rescue
      e ->
        Logger.error("Serializer exception #{inspect(e)} for #{inspect(object)}")
        {:error, "Internal system error"}
    end
  end

  def serialize(object) do
    Logger.error("Cannot serialize non-struct #{inspect(object)}")
    {:error, "Internal system error"}
  end
end
