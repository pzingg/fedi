defmodule FediServer.Oauth.LoginCache do
  use GenServer

  ## Client API

  @doc """
  Starts the registry with the given options.

  `:name` is always required.
  `:ttl` is cache timeout in seconds, defaults to 600.
  """
  def start_link(opts) do
    _server = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @doc """
  Looks up the data for `key` stored in `server`.

  Returns `{:ok, value}` if it exists, `:error` otherwise.
  """
  def lookup(server, key) do
    GenServer.call(server, {:lookup, key})
  end

  @doc """
  Ensures there is value associated with the given `key` in `server`.
  """
  def cache(server, key, value) do
    GenServer.cast(server, {:cache, key, value})
  end

  ## Server callbacks

  @impl true
  def init(opts) do
    table = Keyword.fetch!(opts, :name)
    ttl = Keyword.get(opts, :ttl, 600)
    table = :ets.new(table, [:named_table, read_concurrency: true])
    {:ok, {table, ttl}}
  end

  @impl true
  def handle_call({:lookup, key}, _from, state) do
    result = lookup_with_ttl(key, state)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:cache, key, value}, {table, _ttl} = state) do
    case lookup_with_ttl(key, state) do
      {:ok, _data} ->
        {:noreply, state}

      {:error, _} ->
        value = Map.put(value, :inserted_at, unix_now())
        :ets.insert(table, {key, value})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, {table, _ttl} = state) do
    :ets.delete_all_objects(table)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp lookup_with_ttl(key, {table, ttl}) do
    case :ets.lookup(table, key) do
      [{^key, value}] ->
        if unix_now() < value.inserted_at + ttl do
          {:ok, value}
        else
          :ets.delete(table, key)
          {:error, :expired}
        end

      [] ->
        {:error, :not_found}
    end
  end

  defp unix_now, do: DateTime.utc_now() |> DateTime.to_unix()
end
