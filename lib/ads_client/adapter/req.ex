defmodule AdsClient.Adapter.Req do
  @moduledoc """
  Req-based HTTP adapter with retries, backoff, and telemetry.
  """

  @behaviour AdsClient.Adapter

  alias AdsClient.{Error, Config}

  require Logger

  @impl true
  def request(method, url, headers, body, opts) do
    config = Config.get()

    req_opts = [
      method: method,
      url: url,
      headers: headers,
      json: body,
      retry: :transient,
      max_retries: Keyword.get(opts, :max_retries, config.max_retries),
      retry_delay: &retry_delay/1,
      connect_options: [timeout: config.default_timeout]
    ]

    metadata = %{
      method: method,
      url: url,
      adapter: __MODULE__
    }

    start_time = System.monotonic_time()
    :telemetry.execute([:ads_client, :request, :start], %{}, metadata)

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: body, headers: headers}} when status in 200..299 ->
        duration = System.monotonic_time() - start_time
        :telemetry.execute(
          [:ads_client, :request, :stop],
          %{duration: duration},
          Map.put(metadata, :status, status)
        )

        {:ok, %{status: status, body: body, headers: headers}}

      {:ok, %Req.Response{status: status, body: body}} ->
        duration = System.monotonic_time() - start_time
        error = build_error(status, body)

        :telemetry.execute(
          [:ads_client, :request, :stop],
          %{duration: duration},
          Map.merge(metadata, %{status: status, error: error.type})
        )

        {:error, error}

      {:error, exception} ->
        duration = System.monotonic_time() - start_time
        error = %Error{
          type: :network,
          message: Exception.message(exception),
          details: %{exception: exception}
        }

        :telemetry.execute(
          [:ads_client, :request, :exception],
          %{duration: duration},
          Map.merge(metadata, %{error: error.type, exception: exception})
        )

        {:error, error}
    end
  end

  defp retry_delay(retry_count) do
    config = Config.get()
    base_delay = config.retry_delay
    multiplier = config.backoff_multiplier
    jitter = config.jitter

    delay = trunc(base_delay * :math.pow(multiplier, retry_count - 1))
    jitter_amount = trunc(delay * jitter * (:rand.uniform() * 2 - 1))

    max(0, delay + jitter_amount)
  end

  defp build_error(429, body) do
    %Error{
      type: :rate_limit,
      message: "Rate limit exceeded",
      status: 429,
      body: body,
      details: %{retry_after: get_retry_after(body)}
    }
  end

  defp build_error(status, body) when status >= 500 do
    %Error{
      type: :server,
      message: "Server error",
      status: status,
      body: body
    }
  end

  defp build_error(status, body) when status >= 400 do
    %Error{
      type: :api,
      message: "API error",
      status: status,
      body: body
    }
  end

  defp get_retry_after(body) when is_map(body) do
    Map.get(body, "retry_after")
  end
  defp get_retry_after(_), do: nil
end
