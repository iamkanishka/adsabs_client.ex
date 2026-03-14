defmodule ADSABSClient.HTTP do
  @moduledoc """
  Core HTTP client for ADSABSClient.

  Implements `ADSABSClient.HTTP.Behaviour` with:
  - Bearer token authentication
  - Automatic retry with exponential backoff + jitter
  - Telemetry emission on every request
  - Rate-limit header parsing and warning
  - Structured error conversion via `ADSABSClient.Error`
  """

  @behaviour ADSABSClient.HTTP.Behaviour

  alias ADSABSClient.{Config, Error, RateLimitInfo, Telemetry}

  require Logger

  @repo_url "https://github.com/iamkanishka/adsabs_client.ex"
  @user_agent "adsabs_client.ex/#{Mix.Project.config()[:version]} (Elixir; +#{@repo_url})"

  # Retryable HTTP status codes
  @retryable_statuses [429, 500, 502, 503, 504]

  @doc """
  Returns the configured HTTP client module.

  Defaults to `ADSABSClient.HTTP` (this module). In tests, override with:

      Application.put_env(:adsabs_client, :http_client, ADSABSClient.HTTP.Mock)
  """
  @spec client() :: module()
  def client do
    Application.get_env(:adsabs_client, :http_client, __MODULE__)
  end

  @doc false
  @impl true
  @spec get(String.t(), keyword()) :: ADSABSClient.HTTP.Behaviour.result()
  def get(path, opts \\ []) do
    request(:get, path, nil, opts)
  end

  @doc false
  @impl true
  @spec post(String.t(), map(), keyword()) :: ADSABSClient.HTTP.Behaviour.result()
  def post(path, body, opts \\ []) do
    request(:post, path, body, opts)
  end

  @doc false
  @impl true
  @spec put(String.t(), map(), keyword()) :: ADSABSClient.HTTP.Behaviour.result()
  def put(path, body, opts \\ []) do
    request(:put, path, body, opts)
  end

  @doc false
  @impl true
  @spec delete(String.t(), keyword()) :: ADSABSClient.HTTP.Behaviour.result()
  def delete(path, opts \\ []) do
    request(:delete, path, nil, opts)
  end

  # --- Private ---

  defp request(method, path, body, opts) do
    max_retries = Config.get(:max_retries, 3)
    do_request_with_retry(method, path, body, opts, 0, max_retries)
  end

  defp do_request_with_retry(method, path, body, opts, attempt, max_retries) do
    start_time = System.monotonic_time()
    Telemetry.emit_request_start(path, method, opts[:params] || %{})

    ctx = %{
      method: method,
      path: path,
      body: body,
      opts: opts,
      attempt: attempt,
      max_retries: max_retries,
      start_time: start_time
    }

    try do
      result = execute_request(method, path, body, opts)
      handle_result(result, ctx)
    rescue
      e ->
        Telemetry.emit_request_exception(start_time, path, :error, e)
        {:error, Error.network_error(e)}
    catch
      :exit, reason ->
        Telemetry.emit_request_exception(start_time, path, :exit, reason)
        {:error, Error.network_error(reason)}
    end
  end

  # Bundle repeated context into a map to keep handle_result/2 arity manageable.
  defp handle_result({:ok, %{status: status} = resp}, ctx) when status in @retryable_statuses do
    rate_info = RateLimitInfo.from_headers(resp.headers)
    maybe_emit_rate_limit_events(ctx.path, rate_info, status)

    if ctx.attempt < ctx.max_retries do
      backoff = compute_backoff(ctx.attempt)
      Telemetry.emit_retry_attempt(ctx.path, ctx.attempt + 1, backoff, status)
      :timer.sleep(backoff)
      do_request_with_retry(ctx.method, ctx.path, ctx.body, ctx.opts, ctx.attempt + 1, ctx.max_retries)
    else
      Telemetry.emit_request_stop(ctx.start_time, ctx.path, ctx.method, status, rate_info)
      {:error, Error.from_response(resp)}
    end
  end

  defp handle_result({:ok, %{status: status} = resp}, ctx) when status in 200..299 do
    rate_info = RateLimitInfo.from_headers(resp.headers)
    check_rate_limit_warning(ctx.path, rate_info)
    ADSABSClient.RateLimiter.record(rate_info)
    Telemetry.emit_request_stop(ctx.start_time, ctx.path, ctx.method, status, rate_info)
    {:ok, %{resp | body: resp.body}}
  end

  defp handle_result({:ok, resp}, ctx) do
    rate_info = RateLimitInfo.from_headers(resp.headers)
    Telemetry.emit_request_stop(ctx.start_time, ctx.path, ctx.method, resp.status, rate_info)
    {:error, Error.from_response(resp)}
  end

  defp handle_result({:error, %{reason: reason}}, ctx) do
    if ctx.attempt < ctx.max_retries do
      backoff = compute_backoff(ctx.attempt)
      Telemetry.emit_retry_attempt(ctx.path, ctx.attempt + 1, backoff, reason)
      :timer.sleep(backoff)
      do_request_with_retry(ctx.method, ctx.path, ctx.body, ctx.opts, ctx.attempt + 1, ctx.max_retries)
    else
      Telemetry.emit_request_exception(ctx.start_time, ctx.path, :error, reason)
      {:error, Error.network_error(reason)}
    end
  end

  defp execute_request(method, path, body, opts) do
    base_url = Config.get(:base_url, "https://api.adsabs.harvard.edu/v1")
    token = Config.api_token!()

    req_opts =
      [
        base_url: base_url,
        url: path,
        method: method,
        headers: build_headers(token, opts),
        connect_options: [timeout: Config.get(:connect_timeout, 5_000)],
        receive_timeout: Config.get(:receive_timeout, 30_000),
        decode_body: false
      ]
      |> maybe_put_params(opts[:params])
      |> maybe_put_body(body, Keyword.get(opts, :content_type))

    response = Req.request!(req_opts)

    body =
      if content_is_json?(get_in(response.headers, ["content-type"])) do
        case Jason.decode(response.body) do
          {:ok, decoded} -> decoded
          {:error, _} -> response.body
        end
      else
        response.body
      end

    headers =
      Enum.flat_map(response.headers, fn
        {k, v} when is_list(v) -> Enum.map(v, &{k, &1})
        {k, v} -> [{k, v}]
      end)

    {:ok, %{status: response.status, headers: headers, body: body}}
  rescue
    e in Req.TransportError ->
      {:error, %{reason: e.reason}}
  end

  defp build_headers(token, opts) do
    base = [
      {"Authorization", "Bearer #{token}"},
      {"User-Agent", @user_agent},
      {"Accept", "application/json"}
    ]

    extra = Keyword.get(opts, :headers, [])
    base ++ extra
  end

  defp maybe_put_params(req_opts, nil), do: req_opts
  defp maybe_put_params(req_opts, params), do: Keyword.put(req_opts, :params, params)

  defp maybe_put_body(req_opts, nil, _content_type), do: req_opts

  defp maybe_put_body(req_opts, body, content_type) when is_binary(body) do
    # Plain-text body (e.g. bigquery CSV format); default to text/plain
    ct = content_type || "text/plain"

    req_opts
    |> Keyword.put(:body, body)
    |> Keyword.update!(:headers, &[{"Content-Type", ct} | &1])
  end

  defp maybe_put_body(req_opts, body, _content_type) do
    # JSON body (maps, lists)
    req_opts
    |> Keyword.put(:json, body)
    |> Keyword.update!(:headers, &[{"Content-Type", "application/json"} | &1])
  end

  defp content_is_json?(nil), do: false
  defp content_is_json?(ct) when is_list(ct), do: Enum.any?(ct, &content_is_json?/1)
  defp content_is_json?(ct) when is_binary(ct), do: String.contains?(ct, "json")

  defp compute_backoff(attempt) do
    base = Config.get(:base_backoff_ms, 500)
    max = Config.get(:max_backoff_ms, 30_000)
    # Exponential backoff with full jitter
    cap = round(min(base * :math.pow(2, attempt), max))
    :rand.uniform(cap)
  end

  defp maybe_emit_rate_limit_events(path, rate_info, 429) do
    Telemetry.emit_rate_limit_exceeded(path, rate_info.limit || 60)
  end

  defp maybe_emit_rate_limit_events(path, rate_info, _status) do
    check_rate_limit_warning(path, rate_info)
  end

  defp check_rate_limit_warning(path, rate_info) do
    threshold = Config.get(:rate_limit_warning_threshold, 100)

    if RateLimitInfo.low?(rate_info, threshold) do
      Telemetry.emit_rate_limit_warning(
        path,
        rate_info.remaining,
        rate_info.limit,
        rate_info.reset_at
      )
    end
  end
end
