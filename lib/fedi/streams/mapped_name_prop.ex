defmodule Fedi.Streams.MappedNameProp do
  @moduledoc false

  @enforce_keys [:mapped, :unmapped]
  defstruct [
    :mapped,
    :unmapped
  ]

  @type t() :: %__MODULE__{
          mapped: term(),
          unmapped: term()
        }
end
