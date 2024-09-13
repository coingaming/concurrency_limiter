defmodule ConcurrencyLimiterTest do
  use ExUnit.Case

  test "starts with start_link/1 " do
    assert {:ok, pid} = ConcurrencyLimiter.start_link(max_concurrency: 5)
    assert is_pid(pid)
  end

  test "register a name with :name" do
    assert {:ok, pid} = ConcurrencyLimiter.start_link(name: TestLimiter, max_concurrency: 5)
    assert Process.whereis(TestLimiter) == pid
  end

  test "start_link/1 fails if :max_concurrency is not a positive integer" do
    assert_raise KeyError, fn ->
      ConcurrencyLimiter.start_link([])
    end

    assert_raise ArgumentError, fn ->
      ConcurrencyLimiter.start_link(max_concurrency: -5)
    end

    assert_raise ArgumentError, fn ->
      ConcurrencyLimiter.start_link(max_concurrency: 0)
    end
  end

  test "run!/3 exits if limiter doesn't exist" do
    assert {:noproc, {ConcurrencyLimiter, :run!, [TestLimiter, 5000, _]}} =
             catch_exit(ConcurrencyLimiter.run!(TestLimiter, 5000, fn -> :ok end))
  end

  test "run!/3 runs a function if limiter exists" do
    assert {:ok, limiter} = ConcurrencyLimiter.start_link(max_concurrency: 5)

    {:ok, :result} =
      ConcurrencyLimiter.run!(limiter, 5000, fn ->
        {:ok, :result}
      end)
  end

  test "run!/3 limits concurrency and enqueues workers" do
    assert {:ok, limiter} = ConcurrencyLimiter.start_link(max_concurrency: 3)
    test_pid = self()

    pfun = fn ->
      ConcurrencyLimiter.run!(limiter, 5000, fn ->
        send(test_pid, :started)

        receive do
          :finish -> :ok
        end
      end)
    end

    p1 = spawn(pfun)
    _p2 = spawn(pfun)
    _p3 = spawn(pfun)

    assert_receive :started
    assert_receive :started
    assert_receive :started

    spawn(fn ->
      ConcurrencyLimiter.run!(limiter, 5000, fn ->
        send(test_pid, :p4_started)
      end)
    end)

    refute_receive :p4_started, 300

    send(p1, :finish)

    assert_receive :p4_started
  end

  test "run!/3 timeout" do
    assert {:ok, limiter} = ConcurrencyLimiter.start_link(max_concurrency: 3)
    test_pid = self()

    pfun = fn ->
      ConcurrencyLimiter.run!(limiter, 5000, fn ->
        send(test_pid, :started)

        receive do
          :finish -> :ok
        end
      end)
    end

    _p1 = spawn(pfun)
    _p2 = spawn(pfun)
    _p3 = spawn(pfun)

    assert_receive :started
    assert_receive :started
    assert_receive :started

    Process.flag(:trap_exit, true)

    {pid, ref} =
      spawn_monitor(fn ->
        ConcurrencyLimiter.run!(limiter, 200, fn ->
          :i_will_crash_due_to_timeout
        end)
      end)

    assert_receive {:DOWN, ^ref, :process, ^pid, {:timeout, {ConcurrencyLimiter, :run!, _}}}, 300
  end
end
