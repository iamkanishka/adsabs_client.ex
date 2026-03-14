defmodule ADSABSClient.TelemetryTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias ADSABSClient.{RateLimitInfo, Telemetry}

  # Unique handler ID per test to avoid conflicts in async-false suite
  @handler_prefix "adsabs-test-telemetry"

  setup do
    on_exit(fn ->
      handlers = :telemetry.list_handlers([])

      handlers
      |> Enum.filter(&String.starts_with?(to_string(&1.id), @handler_prefix))
      |> Enum.each(&:telemetry.detach(&1.id))
    end)

    :ok
  end

  defp attach_collector(events) do
    test_pid = self()
    handler_id = "#{@handler_prefix}-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    handler_id
  end

  describe "emit_request_start/3" do
    test "emits [:adsabs_client, :request, :start] event" do
      attach_collector([[:adsabs_client, :request, :start]])

      Telemetry.emit_request_start("/search/query", :get, %{"q" => "stars"})

      assert_receive {:telemetry_event, [:adsabs_client, :request, :start], measurements, metadata}

      assert Map.has_key?(measurements, :system_time)
      assert metadata.endpoint == "/search/query"
      assert metadata.method == :get
      assert metadata.query == %{"q" => "stars"}
    end
  end

  describe "emit_request_stop/5" do
    test "emits [:adsabs_client, :request, :stop] with duration" do
      attach_collector([[:adsabs_client, :request, :stop]])

      start_time = System.monotonic_time()
      :timer.sleep(1)

      rate_info = %RateLimitInfo{limit: 5000, remaining: 4500}
      Telemetry.emit_request_stop(start_time, "/search/query", :get, 200, rate_info)

      assert_receive {:telemetry_event, [:adsabs_client, :request, :stop], measurements, metadata}

      assert measurements.duration > 0
      assert metadata.status == 200
      assert metadata.endpoint == "/search/query"
      assert metadata.method == :get
      assert %RateLimitInfo{} = metadata.rate_limit
    end
  end

  describe "emit_request_exception/4" do
    test "emits [:adsabs_client, :request, :exception]" do
      attach_collector([[:adsabs_client, :request, :exception]])

      start_time = System.monotonic_time()
      Telemetry.emit_request_exception(start_time, "/search/query", :error, :econnrefused)

      assert_receive {:telemetry_event, [:adsabs_client, :request, :exception], measurements, metadata}

      assert Map.has_key?(measurements, :duration)
      assert metadata.endpoint == "/search/query"
      assert metadata.kind == :error
      assert metadata.reason == :econnrefused
    end
  end

  describe "emit_rate_limit_warning/4" do
    test "emits [:adsabs_client, :rate_limit, :warning]" do
      attach_collector([[:adsabs_client, :rate_limit, :warning]])

      reset_at = DateTime.add(DateTime.utc_now(), 3600, :second)
      Telemetry.emit_rate_limit_warning("/export/bibtex", 50, 5000, reset_at)

      assert_receive {:telemetry_event, [:adsabs_client, :rate_limit, :warning], measurements, metadata}

      assert measurements.remaining == 50
      assert measurements.limit == 5000
      assert metadata.endpoint == "/export/bibtex"
      assert metadata.reset_at == reset_at
    end
  end

  describe "emit_rate_limit_exceeded/2" do
    test "emits [:adsabs_client, :rate_limit, :exceeded]" do
      attach_collector([[:adsabs_client, :rate_limit, :exceeded]])

      Telemetry.emit_rate_limit_exceeded("/search/query", 60)

      assert_receive {:telemetry_event, [:adsabs_client, :rate_limit, :exceeded], measurements, metadata}

      assert measurements.retry_after == 60
      assert metadata.endpoint == "/search/query"
    end
  end

  describe "emit_retry_attempt/4" do
    test "emits [:adsabs_client, :retry, :attempt]" do
      attach_collector([[:adsabs_client, :retry, :attempt]])

      Telemetry.emit_retry_attempt("/metrics", 2, 1000, 503)

      assert_receive {:telemetry_event, [:adsabs_client, :retry, :attempt], measurements, metadata}

      assert measurements.attempt == 2
      assert measurements.backoff_ms == 1000
      assert metadata.endpoint == "/metrics"
      assert metadata.reason == 503
    end
  end

  describe "log_handler/4" do
    test "does not raise for :stop events" do
      rate_info = %RateLimitInfo{limit: 5000, remaining: 4500}

      assert :ok =
               Telemetry.log_handler(
                 [:adsabs_client, :request, :stop],
                 %{duration: 100_000},
                 %{endpoint: "/search/query", method: :get, status: 200, rate_limit: rate_info},
                 nil
               )
    end

    test "does not raise for :warning events" do
      assert :ok =
               Telemetry.log_handler(
                 [:adsabs_client, :rate_limit, :warning],
                 %{remaining: 50, limit: 5000},
                 %{endpoint: "/search/query", reset_at: nil},
                 nil
               )
    end

    test "does not raise for :exceeded events" do
      assert :ok =
               Telemetry.log_handler(
                 [:adsabs_client, :rate_limit, :exceeded],
                 %{retry_after: 60},
                 %{endpoint: "/search/query"},
                 nil
               )
    end

    test "does not raise for :exception events" do
      assert :ok =
               Telemetry.log_handler(
                 [:adsabs_client, :request, :exception],
                 %{duration: 0},
                 %{endpoint: "/search/query", kind: :error, reason: :econnrefused},
                 nil
               )
    end

    test "does not raise for unknown events" do
      assert :ok =
               Telemetry.log_handler(
                 [:adsabs_client, :unknown, :event],
                 %{},
                 %{},
                 nil
               )
    end
  end
end
