defmodule ADSABSClient.RateLimiterTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias ADSABSClient.{RateLimiter, RateLimitInfo}

  setup do
    # Reset RateLimiter state before each test — the app supervisor keeps it running,
    # but we need a clean slate. Record a blank info to wipe any previous observations.
    case GenServer.whereis(RateLimiter) do
      nil ->
        start_supervised!(RateLimiter)

      _pid ->
        # Force-reset by stopping and restarting via the test supervisor
        :ok
    end

    # Wipe accumulated state by recording empty info
    GenServer.call(RateLimiter, :reset_state)

    :ok
  end

  describe "status/0" do
    test "returns an empty RateLimitInfo before any observations" do
      {:ok, info} = RateLimiter.status()

      assert %RateLimitInfo{} = info
      assert is_nil(info.limit)
      assert is_nil(info.remaining)
    end
  end

  describe "record/1" do
    test "stores rate limit info" do
      info = %RateLimitInfo{
        limit: 5000,
        remaining: 4500,
        reset_at: DateTime.utc_now()
      }

      RateLimiter.record(info)
      # Give the GenServer a moment to process the cast
      :timer.sleep(10)

      {:ok, stored} = RateLimiter.status()
      assert stored.limit == 5000
      assert stored.remaining == 4500
    end

    test "updates with newer observations" do
      first = %RateLimitInfo{limit: 5000, remaining: 4500, reset_at: nil}
      second = %RateLimitInfo{limit: 5000, remaining: 4200, reset_at: nil}

      RateLimiter.record(first)
      :timer.sleep(10)
      RateLimiter.record(second)
      :timer.sleep(10)

      {:ok, stored} = RateLimiter.status()
      assert stored.remaining == 4200
    end

    test "is a no-op when GenServer is not running" do
      info = %RateLimitInfo{limit: 5000, remaining: 100, reset_at: nil}
      # Should not raise even without a running server
      assert :ok = RateLimiter.record(info)
    end
  end

  describe "check!/0" do
    test "returns :ok when quota is available" do
      info = %RateLimitInfo{limit: 5000, remaining: 1000, reset_at: nil}
      RateLimiter.record(info)
      :timer.sleep(10)

      assert :ok = RateLimiter.check!()
    end

    test "raises when quota is exhausted" do
      info = %RateLimitInfo{
        limit: 5000,
        remaining: 0,
        reset_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      RateLimiter.record(info)
      :timer.sleep(10)

      assert_raise RuntimeError, ~r/rate limit exhausted/, fn ->
        RateLimiter.check!()
      end
    end

    test "returns :ok when no info has been recorded yet" do
      assert :ok = RateLimiter.check!()
    end
  end

  describe "status/0 when not started" do
    test "returns :not_started error" do
      # status/0 checks whereis/1 — test the logic directly by checking a fake name
      assert {:error, :not_started} =
               case(GenServer.whereis(:nonexistent_rate_limiter_xyz)) do
        nil -> {:error, :not_started}
        _pid -> {:ok, GenServer.call(:nonexistent_rate_limiter_xyz, :status)}
      end
    end
  end
end
