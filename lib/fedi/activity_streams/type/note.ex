defmodule Fedi.ActivityStreams.Type.Note do
  @moduledoc """
  Represents a short written work typically less than a single paragraph in
  length.

  Example 53 (https://www.w3.org/TR/activitystreams-vocabulary/#ex52-jsonld):
    {
      "content": "Looks like it is going to rain today. Bring an umbrella!",
      "name": "A Word of Warning",
      "type": "Note"
    }
  """

  defmodule Meta do
    def namespace, do: :activity_streams
    def type_name, do: "Note"
    def disjoint_with, do: ["Link", "Mention"]
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

  def deserialize(m, alias_map) when is_map(m) and is_map(alias_map) do
    Fedi.Streams.BaseType.deserialize(:activity_streams, __MODULE__, m, alias_map)
  end

  def serialize(%__MODULE__{} = object) do
    Fedi.Streams.BaseType.serialize(object)
  end
end
