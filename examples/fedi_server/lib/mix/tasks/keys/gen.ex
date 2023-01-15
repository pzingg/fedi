defmodule Mix.Tasks.Keys.Gen do
  @moduledoc """
  Generates a new private and public key pair, printed on stdout.
  """

  use Mix.Task

  @impl true
  def run(_argv) do
    {:ok, private_key_pem, public_key_pem} = FediServer.HTTPClient.generate_rsa_pem()
    IO.puts(private_key_pem)
    IO.puts(public_key_pem)
  end
end
