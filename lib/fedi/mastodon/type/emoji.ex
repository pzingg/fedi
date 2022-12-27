defmodule Fedi.Mastodon.Type.Emoji do
  @moduledoc """
  Example: Hello world :Kappa:
    {
      "id": "https://example.com/emoji/123",
      "type": "Emoji",
      "name": ":Kappa:",
      "icon": {
        "type": "Image",
        "mediaType": "image/png",
        "url": "https://example.com/files/kappa.png"
      }
    }
  """

  defmodule Meta do
    def type_name, do: "Emoji"
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
