defmodule Fedi.Streams.Serializer do
  @moduledoc false

  require Logger

  alias Fedi.Streams.Utils

  def serialize(%{__struct__: module} = object) do
    try do
      Code.ensure_compiled!(module)
      |> apply(:serialize, [object])
    rescue
      e ->
        {:error, Utils.err_serialization("Serializer exception", exception: e, object: object)}
    end
  end

  def serialize(object) do
    {:error, Utils.err_serialization("Object is not a struct", object: object)}
  end
end
