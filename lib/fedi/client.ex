defmodule Fedi.Client do
  @moduledoc """
  Convenience functions for setting up ActivityPub payloads.
  """

  alias Fedi.ActivityPub.Utils, as: APUtils

  @public_activity_streams "https://www.w3.org/ns/activitystreams#Public"

  def set_visibility(m, :public) do
    m
    |> Map.put("to", [@public_activity_streams | Map.get(m, "to", []) |> List.wrap()] |> unwrap())
  end

  def set_visibility(m, :unlisted) do
    m
    |> remove_public("to")
    |> Map.put("cc", [@public_activity_streams | Map.get(m, "cc", []) |> List.wrap()] |> unwrap())
    |> Map.drop(["audience"])
  end

  def set_visibility(m, :followers_only) do
    m
    |> Map.put("to", get_actor(m) <> "/followers")
    |> Map.drop(["cc", "audience"])
  end

  def set_visibility(m, :direct) do
    m
    |> Map.drop(["cc", "audience"])
  end

  def get_actor(m) do
    (Map.get(m, "actor") || Map.fetch!(m, "attributedTo")) |> unwrap()
  end

  def unwrap([item]), do: item
  def unwrap(l), do: l

  def remove_public(m, prop_name) do
    if Map.has_key?(m, prop_name) do
      prop =
        m[prop_name]
        |> List.wrap()
        |> Enum.map(fn addr ->
          if APUtils.public?(addr) do
            nil
          else
            addr
          end
        end)
        |> Enum.filter(fn addr -> !is_nil(addr) end)

      case prop do
        [] -> Map.delete(m, prop)
        [addr] -> Map.put(m, prop_name, addr)
        _ -> Map.put(m, prop_name, prop)
      end
    else
      m
    end
  end
end
