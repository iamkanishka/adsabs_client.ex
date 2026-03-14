defmodule ADSABSClient.Telemetry do
  @moduledoc """
  Telemetry events emitted by ADSABSClient.

  Attach handlers to these events to integrate with Prometheus, Grafana,
  Datadog, AppSignal, or any `:telemetry`-compatible observability tool.

  ## Events

  ### `[:adsabs_client, :request, :start]`
  Emitted before every HTTP request.
  - **measurements:** `%{system_time: integer()}`
  - **metadata:** `%{endpoint: String.t(), method: atom(), query: map()}`

  ### `[:adsabs_client, :request, :stop]`
  Emitted after a successful HTTP request.
  - **measurements:** `%{duration: integer()}` (native time units)
  - **metadata:** `%{endpoint: String.t(), method: atom(), status: integer(), rate_limit: RateLimitInfo.t()}`

  ### `[:adsabs_client, :request, :exception]`
  Emitted when a request raises an unexpected exception.
  - **measurements:** `%{duration: integer()}`
  - **metadata:** `%{endpoint: String.t(), kind: atom(), reason: term()}`

  ### `[:adsabs_client, :rate_limit, :warning]`
  Emitted when X-RateLimit-Remaining drops below the configured threshold.
  - **measurements:** `%{remaining: integer(), limit: integer()}`
  - **metadata:** `%{endpoint: String.t(), reset_at: DateTime.t() | nil}`

  ### `[:adsabs_client, :rate_limit, :exceeded]`
  Emitted on HTTP 429 responses.
  - **measurements:** `%{retry_after: integer()}`
  - **metadata:** `%{endpoint: String.t()}`

  ### `[:adsabs_client, :retry, :attempt]`
  Emitted on each retry attempt.
  - **measurements:** `%{attempt: integer(), backoff_ms: integer()}`
  - **metadata:** `%{endpoint: String.t(), reason: term()}`

  ## Example: Attaching a Logger Handler

      :telemetry.attach_many(
        "adsabs-logger",
        [
          [:adsabs_client, :request, :stop],
          [:adsabs_client, :rate_limit, :warning]
        ],
        &ADSABSClient.Telemetry.log_handler/4,
        nil
      )

  ## Example: Prometheus Metrics (with telemetry_metrics)

      def metrics do
        [
          Metrics.distribution("adsabs_client.request.duration",
            event_name: [:adsabs_client, :request, :stop],
            measurement: :duration,
            tags: [:endpoint],
            unit: {:native, :millisecond},
            reporter_options: [buckets: [100, 500, 1000, 5000]]
          ),
          Metrics.counter("adsabs_client.rate_limit.exceeded.count",
            event_name: [:adsabs_client, :rate_limit, :exceeded]
          )
        ]
      end
  """

  require Logger

  @doc "Convenience handler that logs telemetry events."
  def log_handler([:adsabs_client, :request, :stop], measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.debug(
      "[ADSABSClient] #{metadata.method |> to_string() |> String.upcase()} " <>
        "#{metadata.endpoint} → #{metadata.status} (#{duration_ms}ms)"
    )
  end

  def log_handler([:adsabs_client, :rate_limit, :warning], measurements, metadata, _config) do
    Logger.warning(
      "[ADSABSClient] Rate limit warning for #{metadata.endpoint}: " <>
        "#{measurements.remaining}/#{measurements.limit} remaining"
    )
  end

  def log_handler([:adsabs_client, :rate_limit, :exceeded], measurements, metadata, _config) do
    Logger.warning(
      "[ADSABSClient] Rate limit exceeded for #{metadata.endpoint}. Retry after #{measurements.retry_after}s"
    )
  end

  def log_handler([:adsabs_client, :retry, :attempt], measurements, metadata, _config) do
    Logger.info(
      "[ADSABSClient] Retry attempt #{measurements.attempt} for #{metadata.endpoint} " <>
        "(backoff: #{measurements.backoff_ms}ms)"
    )
  end

  def log_handler([:adsabs_client, :request, :exception], _measurements, metadata, _config) do
    Logger.error(
      "[ADSABSClient] Request exception for #{metadata.endpoint} [#{metadata.kind}]: #{inspect(metadata.reason)}"
    )
  end

  def log_handler(_event, _measurements, _metadata, _config), do: :ok

  # --- Internal emit helpers ---

  @doc false
  def emit_request_start(endpoint, method, query) do
    :telemetry.execute(
      [:adsabs_client, :request, :start],
      %{system_time: System.system_time()},
      %{endpoint: endpoint, method: method, query: query}
    )
  end

  @doc false
  def emit_request_stop(start_time, endpoint, method, status, rate_limit) do
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:adsabs_client, :request, :stop],
      %{duration: duration},
      %{endpoint: endpoint, method: method, status: status, rate_limit: rate_limit}
    )
  end

  @doc false
  def emit_request_exception(start_time, endpoint, kind, reason) do
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:adsabs_client, :request, :exception],
      %{duration: duration},
      %{endpoint: endpoint, kind: kind, reason: reason}
    )
  end

  @doc false
  def emit_rate_limit_warning(endpoint, remaining, limit, reset_at) do
    :telemetry.execute(
      [:adsabs_client, :rate_limit, :warning],
      %{remaining: remaining, limit: limit},
      %{endpoint: endpoint, reset_at: reset_at}
    )
  end

  @doc false
  def emit_rate_limit_exceeded(endpoint, retry_after) do
    :telemetry.execute(
      [:adsabs_client, :rate_limit, :exceeded],
      %{retry_after: retry_after},
      %{endpoint: endpoint}
    )
  end

  @doc false
  def emit_retry_attempt(endpoint, attempt, backoff_ms, reason) do
    :telemetry.execute(
      [:adsabs_client, :retry, :attempt],
      %{attempt: attempt, backoff_ms: backoff_ms},
      %{endpoint: endpoint, reason: reason}
    )
  end
end
