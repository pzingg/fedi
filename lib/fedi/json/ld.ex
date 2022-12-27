defmodule Fedi.JSON.LD do
  @moduledoc """
  JSON.LD vocabulary.
  """

  @all_properties ["id", "type"]

  def type_modules(), do: []

  def properties() do
    @all_properties
    |> Enum.map(fn prop_name ->
      {initial, rest} = String.split_at(prop_name, 1)
      cap = String.upcase(initial)
      {prop_name, Module.concat([Fedi, JSON, LD, Property, cap <> rest])}
    end)
  end

  def has_map_property(_prop_name), do: false
end
