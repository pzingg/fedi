defmodule Fedi.Toot do
  @moduledoc """
  Toot vocabulary.
  """

  @namespace_mod Module.split(__MODULE__) |> List.last()

  @all_types [
    Fedi.Toot.Type.Emoji,
    Fedi.Toot.Type.IdentityProof
  ]

  @all_properties [
    "blurhash",
    "discoverable",
    "signatureAlgorithm",
    "signatureValue",
    "votersCount"
  ]

  @property_info @all_properties
                 |> Enum.map(fn prop_name ->
                   {initial, rest} = String.split_at(prop_name, 1)
                   cap = String.upcase(initial)
                   {prop_name, Module.concat(["Fedi", @namespace_mod, "Property", cap <> rest])}
                 end)

  def properties(), do: @property_info

  def type_modules() do
    @all_types
  end

  def has_map_property?(_prop_name), do: false
end
