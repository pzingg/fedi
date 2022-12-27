defmodule SecurityV1.Type.PublicKey do
  @moduledoc """
  A public key represents a public cryptographical key for a user.
  """

  defmodule Meta do
    def type_name, do: "PublicKey"
    def disjoint_with, do: []
    def extended_by, do: []
    def extends, do: []
  end

  @enforce_keys [:alias]
  defstruct [
    :alias,
    :unknown,
    properties: %{}
  ]

  @type t() :: %__MODULE__{
          alias: String.t(),
          properties: map(),
          unknown: term()
        }

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseType.deserialize(:security_v1, __MODULE__, m, alias_map)
  end

  def serialize(%__MODULE__{} = object) do
    Fedi.Streams.BaseType.serialize(object)
  end
end
