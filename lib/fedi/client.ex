defmodule Fedi.Client do
  @moduledoc """
  Convenience functions for setting up ActivityPub payloads.
  """

  @public_activity_streams "https://www.w3.org/ns/activitystreams#Public"

  def set_visibility(m, :public) do
    m
    |> Map.put("to", [@public_activity_streams | Map.get(m, "to", []) |> List.wrap()])
  end

  def set_visibility(m, :unlisted) do
    m
    |> Map.update("to", get_actor(m), fn to ->
      List.wrap(to) |> List.delete(@public_activity_streams)
    end)
    |> Map.put("cc", [@public_activity_streams | Map.get(m, "cc", []) |> List.wrap()])
    |> Map.drop(["audience"])
  end

  def set_visibility(m, :followers_only) do
    m
    |> Map.put("to", [get_actor(m) <> "/followers"])
    |> Map.drop(["cc", "audience"])
  end

  def set_visibility(m, :direct) do
    m
    |> Map.drop(["cc", "audience"])
  end

  def get_actor(m) do
    Map.get(m, "actor") || Map.fetch!(m, "attributedTo")
  end
end
