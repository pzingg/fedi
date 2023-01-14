defmodule Fedi.Streams.Error do
  @moduledoc """
  Encapsulates errors encountered during ActivityStreams
  deserialization and ActivityPub processing.
  """

  @enforce_keys [:code, :message]
  defstruct [
    :code,
    :message,
    internal?: false,
    data: []
  ]

  @type t() :: %__MODULE__{
          code: atom(),
          message: String.t(),
          internal?: boolean(),
          data: Keyword.t()
        }

  def new(code, message, internal? \\ false, data \\ []) do
    %__MODULE__{code: code, message: message, internal?: internal?, data: data}
  end

  def response_message(%__MODULE__{internal?: true}), do: "Internal system error"

  def response_message(%__MODULE__{}), do: "Bad request"
end

defimpl String.Chars, for: Fedi.ActivityPub.Error do
  def to_string(%{message: message}) do
    message
  end
end
