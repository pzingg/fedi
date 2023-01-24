defmodule Fedi.Streams.Error do
  @moduledoc """
  Encapsulates errors encountered during ActivityStreams
  deserialization and ActivityPub processing.
  """

  @enforce_keys [:code, :status, :message]
  defstruct [
    :code,
    :status,
    :message,
    data: []
  ]

  @type t() :: %__MODULE__{
          code: atom(),
          status: atom(),
          message: String.t(),
          data: Keyword.t()
        }

  def new(code, message, status \\ :internal_server_error, data \\ []) do
    %__MODULE__{code: code, message: message, status: status, data: data}
  end
end

defimpl String.Chars, for: Fedi.Streams.Error do
  def to_string(%{message: message}) do
    message
  end
end
