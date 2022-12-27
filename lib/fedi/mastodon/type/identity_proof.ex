defmodule Fedi.Mastodon.Type.IdentityProof do
  @moduledoc false

  defmodule Meta do
    def type_name, do: "IdentityProof"
    def disjoint_with, do: []
    def extended_by, do: []
    def extends, do: ["Object"]
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

  def deserialize(m, alias_map) do
    Fedi.Streams.BaseType.deserialize(:mastodon, __MODULE__, m, alias_map)
  end
end
