defmodule ADSABSClient.RateLimiter do
  @moduledoc """
  GenServer that tracks rate-limit state across all requests.

  Automatically started as part of the `ADSABSClient.Application` supervision
  tree. Stores the most recent `X-RateLimit-*` header values from every
  ADS API response and provides:

  - `status/0` — current limit/remaining/reset values
  - `record/1` — update state from a new `RateLimitInfo`
  - `check!/0` — raises if quota is fully exhausted

  ## Usage

      # Check current quota
      {:ok, info} = ADSABSClient.RateLimiter.status()
      info.remaining   # => 4230
      info.reset_at    # => ~U[2026-03-14 00:00:00Z]

      # Manually register a new rate-limit observation
      ADSABSClient.RateLimiter.record(rate_limit_info)
  """

  use GenServer

  alias ADSABSClient.{Config, RateLimitInfo, Telemetry}

  require Logger

  # --- Public API ---

  @doc "Start the RateLimiter under the application supervisor."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Return the most recently observed rate-limit info.

  Returns `{:ok, %RateLimitInfo{}}` or `{:error, :not_started}`.
  """
  @spec status() :: {:ok, RateLimitInfo.t()} | {:error, :not_started}
  def status do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_started}
      _pid -> {:ok, GenServer.call(__MODULE__, :status)}
    end
  end

  @doc """
  Record a new `RateLimitInfo` observation (called after each HTTP response).
  No-op if the GenServer is not running.
  """
  @spec record(RateLimitInfo.t()) :: :ok
  def record(%RateLimitInfo{} = info) do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      _pid -> GenServer.cast(__MODULE__, {:record, info})
    end
  end

  @doc """
  Raise if the quota is completely exhausted.

  Use this to guard expensive batch operations before starting them.
  """
  @spec check!() :: :ok
  def check! do
    case status() do
      {:ok, %RateLimitInfo{remaining: 0, reset_at: reset_at}} ->
        raise """
        ADSABSClient: ADS API rate limit exhausted.
        Quota resets at: #{inspect(reset_at)}
        """

      _ ->
        :ok
    end
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_opts) do
    state = %{
      info: %RateLimitInfo{},
      last_updated: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state.info, state}
  end

  @impl true
  def handle_call(:reset_state, _from, _state) do
    {:reply, :ok, %{info: %RateLimitInfo{}, last_updated: nil}}
  end

  @impl true
  def handle_cast({:record, %RateLimitInfo{} = info}, state) do
    threshold = Config.get(:rate_limit_warning_threshold, 100)

    # Emit warning telemetry if we crossed the threshold
    if RateLimitInfo.low?(info, threshold) and not RateLimitInfo.low?(state.info, threshold) do
      Telemetry.emit_rate_limit_warning(
        "global",
        info.remaining,
        info.limit,
        info.reset_at
      )
    end

    new_state = %{state | info: info, last_updated: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:reset_check, state) do
    # Check if the reset window has passed and reset our state
    now = DateTime.utc_now()

    new_state =
      case state.info.reset_at do
        nil ->
          state

        reset_at ->
          if DateTime.compare(now, reset_at) == :gt do
            Logger.debug("[ADSABSClient.RateLimiter] Rate limit window reset")
            %{state | info: %RateLimitInfo{}}
          else
            state
          end
      end

    schedule_reset_check()
    {:noreply, new_state}
  end

  # --- Private ---

  defp schedule_reset_check do
    # Check every 5 minutes if the window has passed
    Process.send_after(self(), :reset_check, :timer.minutes(5))
  end
end
