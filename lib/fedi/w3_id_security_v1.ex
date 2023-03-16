defmodule Fedi.W3IDSecurityV1 do
  @moduledoc """
  W3IDSecurityV1 vocabulary.
  """

  @namespace_mod Module.split(__MODULE__) |> List.last()

  @all_types [
    Fedi.W3IDSecurityV1.Type.PublicKey
  ]

  @all_type_names Enum.map(@all_types, fn mod -> Module.split(mod) |> List.last() end)

  @all_properties [
    "owner",
    "publicKey",
    "publicKeyPem"
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

  def get_type_module(type_name) do
    if Enum.member?(@all_type_names, type_name) do
      Module.concat(["Fedi", "W3IDSecurityV1", "Type", type_name])
    else
      nil
    end
  end

  def has_map_property?(_prop_name), do: false
end
