defmodule Fedi.ActivityStreams.Property.OneOf do
  @moduledoc false

  require Logger

  @prop_name "oneOf"

  @enforce_keys :alias
  defstruct [
    :alias,
    properties: []
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          properties: list()
        }

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseProperty.deserialize_properties(
      :activity_streams,
      __MODULE__,
      @prop_name,
      m,
      alias_map
    )
  end
end
