defmodule Fedi.Mastodon do
  @moduledoc """
  Mastodon vocabulary.
  """

  @all_types [
    Fedi.Mastodon.Type.Emoji,
    Fedi.Mastodon.Type.IdentityProof
  ]

  @all_properties [
    "blurhash",
    "discoverable",
    "signatureAlgorithm",
    "signatureValue",
    "votersCount"
  ]

  def type_modules() do
    @all_types
  end

  def properties() do
    @all_properties
    |> Enum.map(fn prop_name ->
      {initial, rest} = String.split_at(prop_name, 1)
      cap = String.upcase(initial)
      {prop_name, Module.concat([Fedi, Mastodon, Property, cap <> rest])}
    end)
  end

  def has_map_property(_prop_name), do: false
end
