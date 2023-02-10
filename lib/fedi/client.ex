defmodule Fedi.Client do
  @moduledoc """
  Convenience functions for setting up ActivityPub payloads.
  """

  require Logger

  alias Fedi.ActivityPub.Utils, as: APUtils

  @public_activity_streams "https://www.w3.org/ns/activitystreams#Public"

  def set_visibility(m, actor_iri, visibility) do
    to = Map.get(m, "to", []) |> List.wrap() |> Enum.reject(&APUtils.public?(&1))
    cc = Map.get(m, "cc", []) |> List.wrap() |> Enum.reject(&APUtils.public?(&1))

    {to, cc} =
      case visibility do
        :public ->
          {[@public_activity_streams | to], ["#{actor_iri}/followers" | cc]}

        :unlisted ->
          {to, [@public_activity_streams | ["#{actor_iri}/followers" | cc]]}

        :followers_only ->
          {to, ["#{actor_iri}/followers" | cc]}

        :direct ->
          {to, cc}
      end

    to =
      if Enum.empty?(to) do
        [actor_iri]
      else
        MapSet.new(to) |> MapSet.to_list()
      end

    cc = Enum.reject(cc, &Enum.member?(to, &1)) |> MapSet.new() |> MapSet.to_list()
    m = Map.put(m, "to", unwrap(to))

    case unwrap(cc) do
      nil -> Map.delete(m, "cc")
      c -> Map.put(m, "cc", c)
    end
  end

  def get_actor(m) do
    (Map.get(m, "actor") || Map.fetch!(m, "attributedTo")) |> unwrap()
  end

  def unwrap([]), do: nil
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
        |> Enum.reject(&is_nil/1)

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
