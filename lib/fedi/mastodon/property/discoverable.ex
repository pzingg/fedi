defmodule Fedi.Mastodon.Property.Discoverable do
  @moduledoc false

  require Logger

  @prop_name "discoverable"

  @enforce_keys :alias
  defstruct [
    :alias,
    values: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          values: list()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseProperty.deserialize_values(
      :mastodon,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end

  def serialize(%__MODULE__{} = prop) do
    Fedi.Streams.BaseProperty.serialize_values(prop)
  end

  # new creates a new type property.
  def new() do
    %__MODULE__{alias: ""}
  end

  # name returns the name of this property: "id".
  def name(%__MODULE__{alias: alias_}) do
    Fedi.Streams.BaseProperty.name(@prop_name, alias_)
  end

  # clear ensures no value of this property is set
  def clear(%__MODULE__{} = prop) do
    Fedi.Streams.PropertyIterator.clear(prop)
  end
end
