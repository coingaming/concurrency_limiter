# ConcurrencyLimiter

A simple resource pool that limits concurrency up to a number. Processes can wait
in queue with a timeout.

Powered by Nimble Pool.

Example usage:
```elixir
{:ok, pid} = ConcurrencyLimiter.start_link(max_concurrency: 5)

ConcurrencyLimiter.run!(pid, 5000, fn ->
  # Do some work
end)
```
With a name:
```elixir
ConcurrencyLimiter.start_link(name: MyLimiter, max_concurrency: 5)

ConcurrencyLimiter.run(MyLimiter, 5000, fn ->
  # Do some work
end)

```
Or with a supervisor:
```elixir
Supervisor.start_link([
  {ConcurrencyLimiter, name: LimiterA, max_concurrency: 5},
  {ConcurrencyLimiter, name: LimiterB, max_concurrency: 10},
  {ConcurrencyLimiter, name: LimiterC, max_concurrency: 50}
], strategy: :one_for_one)

ConcurrencyLimiter.run(LimiterB, 5000, fn ->
  # Do some work
end)
```

## Installation

The package can be installed by adding `concurrency_limiter` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:concurrency_limiter, "~> 1.0"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/concurrency_limiter>.
