defmodule Fedi.ActivityStreams.Type.Document do
  @moduledoc """
  Represents a document of any kind.

  Example 49 (https://www.w3.org/TR/activitystreams-vocabulary/#ex48-jsonld):
    {
      "name": "4Q Sales Forecast",
      "type": "Document",
      "url": "http://example.org/4q-sales-forecast.pdf"
    }
  """

  defmodule Meta do
    def type_name, do: "Document"
    def disjoint_with, do: ["Link", "Mention"]
    def extended_by, do: ["Audio", "Image", "Page", "Video"]
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

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end

  def serialize(%__MODULE__{} = object) do
    Fedi.Streams.BaseType.serialize(object)
  end
end
