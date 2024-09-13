defmodule ConcurrencyLimiter do
  @moduledoc """
  A simple resource pool that limits concurrency up to a number. Processes can wait
  in queue with a timeout.

  Powered by Nimble Pool.

  Processes can wait in queue with a timeout.

  Examples:

      iex> {:ok, pid} = ConcurrencyLimiter.start_link(max_concurrency: 5)
      {:ok, pid}

      iex> ConcurrencyLimiter.run(pid, 5000, fn ->
        # Do some work
        :ok
      end)
      :ok

      # Also accepts a name:
      iex> {:ok, pid} = ConcurrencyLimiter.start_link(name: MyLimiter, max_concurrency: 5)
      {:ok, pid}

      iex> ConcurrencyLimiter.run(MyLimiter, 5000, fn ->
        # Do some work
        :ok
      end)
      :ok

      # Or with a supervisor:
      iex> Supervisor.start_link([
        {ConcurrencyLimiter, name: LimiterA, max_concurrency: 5},
        {ConcurrencyLimiter, name: LimiterB, max_concurrency: 10},
        {ConcurrencyLimiter, name: LimiterC, max_concurrency: 50}
      ], strategy: :one_for_one)
  """

  @behaviour NimblePool

  # Public API

  @doc """
  Starts a concurrency limiter

  Accepts two options:

  - `:max_concurrency` - Maximum concurrency. Required.
  - `:name` - name of the concurrency limiter
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    max_concurrency = Keyword.fetch!(opts, :max_concurrency)
    name = Keyword.get(opts, :name)

    if not is_integer(max_concurrency) or max_concurrency <= 0 do
      raise ArgumentError,
            "max concurrency must be an integer bigger than 0, got #{inspect(max_concurrency)}"
    end

    pool_opts = [
      worker: {__MODULE__, name},
      pool_size: max_concurrency
    ]

    pool_opts =
      if name do
        Keyword.put(pool_opts, :name, name)
      else
        pool_opts
      end

    NimblePool.start_link(pool_opts)
  end

  @doc """
  Defines a ConcurrencyLimiter to be started under a supervisor.

  Accepts the same options as `start_link/1`, plus:

  - `:id` - Optional. Defaults to the value of the `:name` option. If `:name`
  is not present, defaults to `ConcurrencyLimiter`. See `Supervisor`
  documentation for more info
  - `:restart` - Optional. See `Supervisor` documentation for more info
  - `:shutdown` - Optional. See `Supervisor` documentation for more info
  """
  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts
    |> Keyword.take([:id, :restart, :shutdown])
    |> Map.new()
    |> Map.put_new(:id, opts[:name] || __MODULE__)
    |> Map.put(:start, {__MODULE__, :start_link, [opts]})
  end

  @doc """
  Run a function with concurrency limited

  Exits if the ConcurrencyLimiter doesn't exist, or if time out.
  """
  @spec run!(GenServer.server(), timeout(), function) :: result
        when function: (-> result), result: var
  def run!(limiter, timeout, fun) when is_function(fun, 0) do
    try do
      NimblePool.checkout!(limiter, :run, fn _, _ -> {fun.(), :ok} end, timeout)
    catch
      :exit, {:noproc, {NimblePool, :checkout, [limiter]}} ->
        exit({:noproc, {__MODULE__, :run!, [limiter, timeout, fun]}})

      :exit, {:timeout, {NimblePool, :checkout, [limiter]}} ->
        exit({:timeout, {__MODULE__, :run!, [limiter, timeout, fun]}})
    end
  end

  # Nimble pool - our workers do nothing, their simple existence is enough for
  # us to use them to control concurrency
  @impl NimblePool
  def init_worker(pool_state) do
    {:ok, make_ref(), pool_state}
  end

  @impl NimblePool
  def handle_checkout(_, _, worker_state, pool_state) do
    {:ok, worker_state, worker_state, pool_state}
  end

  @impl NimblePool
  def handle_checkin(_client_state, _from, worker_state, pool_state) do
    {:ok, worker_state, pool_state}
  end

  @impl NimblePool
  def terminate_worker(_reason, _worker_state, pool_state) do
    {:ok, pool_state}
  end
end
