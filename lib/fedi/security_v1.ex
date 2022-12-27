defmodule Fedi.SecurityV1 do
  @moduledoc """
  SecurityV1 vocabulary.
  """

  @all_types [
    Fedi.SecurityV1.Type.PublicKey
  ]

  @all_properties [
    "owner",
    "publicKey",
    "publicKeyPem"
  ]

  def type_modules() do
    @all_types
  end

  def properties() do
    @all_properties
    |> Enum.map(fn prop_name ->
      {initial, rest} = String.split_at(prop_name, 1)
      cap = String.upcase(initial)
      {prop_name, Module.concat([Fedi, SecurityV1, Property, cap <> rest])}
    end)
  end

  def has_map_property(_prop_name), do: false
end
