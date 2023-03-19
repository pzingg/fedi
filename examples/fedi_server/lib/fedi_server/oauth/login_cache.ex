defmodule FediServer.Oauth.LoginCache do
  @moduledoc """
  Simple ETS cache to hold Oauth data during authorization flow.
  """

  use GenServer

  require Logger

  ## Client API

  @doc """
  Starts the registry with the given options.

  `:name` - unique atom defining the name for an ETS named table, required.
  `:ttl` - cache timeout in milliseconds, optional, defaults to 600_000.

  After initialization, the value of `:name` can be used for
  as the `table` argument in `lookup/2` and `cache/3`.
  """
  def start_link(opts) do
    if Keyword.get(opts, :name) do
      GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name, :timeout]))
    else
      {:error, :name_required}
    end
  end

  @doc """
  Looks up the data for `key` stored in `table`.

  Returns `{:ok, value}` if it exists, `{:error, :not_found}`
  or `{:error, expired}` otherwise.
  """
  def lookup(table, key) do
    GenServer.call(table, {:lookup, key})
  end

  @doc """
  Caches data at the given `key` in `table`.
  """
  def cache(table, key, value) do
    GenServer.cast(table, {:cache, key, value})
  end

  ## Server callbacks

  @impl true
  def init(opts) do
    table = Keyword.fetch!(opts, :name)
    ttl = Keyword.get(opts, :ttl, 600_000)
    table = :ets.new(table, [:named_table, read_concurrency: true])
    {:ok, {table, ttl}}
  end

  @impl true
  def handle_call({:lookup, key}, _from, {table, _ttl} = state) do
    result = lookup_and_purge(table, key)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:cache, key, value}, {table, ttl} = state) do
    case lookup_and_purge(table, key) do
      {:ok, _data} ->
        {:noreply, state}

      {:error, _} ->
        expires = unix_now() + ttl
        :ets.insert(table, {key, expires, value})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, {table, _ttl} = state) do
    :ets.delete_all_objects(table)
    {:noreply, state}
  end

  def handle_info(msg, {table, _ttl} = state) do
    Logger.error(":{table}: unhandled msg #{inspect(msg)}")
    {:noreply, state}
  end

  defp lookup_and_purge(table, key) do
    ts = unix_now()

    result =
      case :ets.lookup(table, key) do
        [{^key, expires, value}] ->
          if expires < ts do
            :ets.delete(table, key)
            {:error, :expired}
          else
            {:ok, value}
          end

        [] ->
          {:error, :not_found}
      end

    _ = purge_expired(table, ts)
    result
  end

  defp purge_expired(table, ts) do
    ms = [{{:_, :"$1", :_}, [{:<, :"$1", ts}], [true]}]

    case :ets.select_delete(table, ms) do
      0 ->
        0

      num_deleted ->
        Logger.debug(":#{table}: #{num_deleted} exprired cache entries were deleted")
        num_deleted
    end
  end

  defp unix_now, do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
end
