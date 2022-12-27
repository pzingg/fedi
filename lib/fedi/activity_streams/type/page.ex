defmodule Fedi.ActivityStreams.Type.Page do
  @moduledoc """
  Represents a Web Page.

  Example 54 (https://www.w3.org/TR/activitystreams-vocabulary/#ex53-jsonld):
    {
      "name": "Omaha Weather Report",
      "type": "Page",
      "url": "http://example.org/weather-in-omaha.html"
    }
  """

  defmodule Meta do
    def type_name, do: "Page"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: []
    def extends, do: ["Document", "Object"]
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
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end
end
