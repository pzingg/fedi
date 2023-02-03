defmodule FediServerWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FediServerWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  require Phoenix.ConnTest

  @endpoint FediServerWeb.Endpoint

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import FediServer.FixturesHelper
      import FediServerWeb.ConnCase

      alias FediServerWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint FediServerWeb.Endpoint
    end
  end

  def fix_request_conn(%Plug.Conn{} = conn) do
    # Why doesn't Phoenix do this?
    url = FediServerWeb.Endpoint.url()
    %URI{scheme: scheme, host: host, port: port} = URI.parse(url)
    %Plug.Conn{conn | scheme: String.to_atom(scheme), host: host, port: port}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = FediServer.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  def sign_and_send(
        %Plug.Conn{} = conn,
        url,
        body,
        %{ap_id: actor_id} = _user,
        keys_pem
      )
      when is_binary(url) and is_binary(body) and is_binary(actor_id) and is_binary(keys_pem) do
    assert {:ok, private_key, _} = FediServer.HTTPClient.decode_keys(keys_pem)
    assert is_tuple(private_key)

    headers =
      FediServer.HTTPClient.signed_headers(
        URI.parse(url),
        private_key,
        actor_id <> "#main-key",
        "test",
        body
      )

    Enum.reduce(headers, conn, fn {name, value}, acc ->
      Plug.Conn.put_req_header(acc, name, value)
    end)
    |> Phoenix.ConnTest.post(url, body)
  end

  setup tags do
    FediServer.DataCase.setup_sandbox(tags)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
