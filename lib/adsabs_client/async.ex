defmodule ADSABSClient.Async do
  @moduledoc """
  Helpers for concurrent ADS API requests using `Task.async_stream/3`.

  When you need to fetch data for many bibcodes or run multiple independent
  queries simultaneously, this module lets you do so concurrently while
  respecting rate limits.

  ## Examples

      bibcode_groups = Enum.chunk_every(my_large_bibcode_list, 50)

      # Fetch metrics for all groups in parallel (max 5 concurrent)
      results = ADSABSClient.Async.fetch_metrics(bibcode_groups)

      # Export each group to BibTeX concurrently
      results = ADSABSClient.Async.export_all(bibcode_groups, :bibtex)

      # Run multiple independent searches concurrently
      queries = ["black holes", "neutron stars", "pulsars"]
      results = ADSABSClient.Async.search_all(queries, rows: 10)

  ## Concurrency vs Rate Limits

  ADS enforces per-endpoint rate limits. The default `max_concurrency` is
  conservative (3) to avoid triggering 429s. Raise it only if you have a
  high daily quota.
  """

  alias ADSABSClient.{Error, Export, Metrics, Search}

  @default_concurrency 3
  @default_timeout 60_000

  @type async_result(t) :: {:ok, t} | {:error, Error.t() | :timeout | :exit}

  @doc """
  Run multiple search queries concurrently.

  Returns a list of `{query, result}` tuples in the same order as the input.

  ## Options

  - `:max_concurrency` — parallel request limit (default: #{@default_concurrency})
  - `:timeout` — per-task timeout in ms (default: #{@default_timeout})
  - All `ADSABSClient.Search.query/2` options are forwarded

  ## Example

      queries = ["black holes", "neutron stars", "pulsars"]

      results = ADSABSClient.Async.search_all(queries, rows: 5)
      # => [
      #   {"black holes", {:ok, %Search.Response{num_found: 12345, ...}}},
      #   {"neutron stars", {:ok, %Search.Response{...}}},
      #   {"pulsars", {:ok, %Search.Response{...}}}
      # ]
  """
  @spec search_all([String.t() | ADSABSClient.Query.t()], keyword()) ::
          [{String.t() | ADSABSClient.Query.t(), async_result(ADSABSClient.Search.Response.t())}]
  def search_all(queries, opts \\ []) when is_list(queries) do
    {async_opts, search_opts} = split_opts(opts)

    stream =
      Task.async_stream(
        queries,
        fn q -> Search.query(q, search_opts) end,
        max_concurrency: async_opts[:max_concurrency] || @default_concurrency,
        timeout: async_opts[:timeout] || @default_timeout,
        on_timeout: :kill_task
      )

    results =
      Enum.map(stream, fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, Error.network_error(:timeout)}
        {:exit, reason} -> {:error, Error.network_error(reason)}
      end)

    Enum.zip(queries, results)
  end

  @doc """
  Fetch metrics for multiple bibcode groups concurrently.

  Useful when you have more bibcodes than the ADS metrics endpoint
  comfortably handles in a single request (recommended max: ~100 per group).

  ## Example

      groups = Enum.chunk_every(bibcodes, 50)

      ADSABSClient.Async.fetch_metrics(groups)
      |> Enum.filter(&match?({_, {:ok, _}}, &1))
      |> Enum.map(fn {_group, {:ok, resp}} -> resp.indicators["h"] end)
  """
  @spec fetch_metrics([[String.t()]], keyword()) ::
          [{[String.t()], async_result(ADSABSClient.Metrics.Response.t())}]
  def fetch_metrics(bibcode_groups, opts \\ []) when is_list(bibcode_groups) do
    {async_opts, metrics_opts} = split_opts(opts)

    stream =
      Task.async_stream(
        bibcode_groups,
        fn group -> Metrics.fetch(group, metrics_opts) end,
        max_concurrency: async_opts[:max_concurrency] || @default_concurrency,
        timeout: async_opts[:timeout] || @default_timeout,
        on_timeout: :kill_task
      )

    results =
      Enum.map(stream, fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, Error.network_error(:timeout)}
        {:exit, reason} -> {:error, Error.network_error(reason)}
      end)

    Enum.zip(bibcode_groups, results)
  end

  @doc """
  Export multiple bibcode groups to a given format concurrently,
  then concatenate the results into a single string.

  ## Example

      groups = Enum.chunk_every(bibcodes, 200)
      {:ok, full_bibtex} = ADSABSClient.Async.export_all(groups, :bibtex)
  """
  @spec export_all([[String.t()]], atom(), keyword()) ::
          {:ok, String.t()} | {:error, [Error.t()]}
  def export_all(bibcode_groups, format, opts \\ []) when is_list(bibcode_groups) do
    {async_opts, export_opts} = split_opts(opts)

    stream =
      Task.async_stream(
        bibcode_groups,
        fn group -> apply(Export, format, [group, export_opts]) end,
        max_concurrency: async_opts[:max_concurrency] || @default_concurrency,
        timeout: async_opts[:timeout] || @default_timeout,
        on_timeout: :kill_task
      )

    results =
      Enum.map(stream, fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, Error.network_error(:timeout)}
        {:exit, reason} -> {:error, Error.network_error(reason)}
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      combined = Enum.map_join(results, "\n", fn {:ok, text} -> text end)

      {:ok, combined}
    else
      {:error, Enum.map(errors, fn {:error, e} -> e end)}
    end
  end

  @doc """
  Resolve multiple bibcodes to their full-text URLs concurrently.

  Returns a map of `%{bibcode => {:ok, url} | {:error, error}}`.

  ## Example

      urls = ADSABSClient.Async.resolve_urls(bibcodes)
      # => %{
      #   "2016PhRvL.116f1102A" => {:ok, "https://journals.aps.org/..."},
      #   "bad_code" => {:error, %Error{type: :not_found}}
      # }
  """
  @spec resolve_urls([String.t()], keyword()) ::
          %{String.t() => async_result(String.t())}
  def resolve_urls(bibcodes, opts \\ []) when is_list(bibcodes) do
    {async_opts, _} = split_opts(opts)

    bibcodes
    |> Task.async_stream(
      fn bibcode ->
        {bibcode, ADSABSClient.Resolver.full_text_url(bibcode)}
      end,
      max_concurrency: async_opts[:max_concurrency] || @default_concurrency,
      timeout: async_opts[:timeout] || @default_timeout,
      on_timeout: :kill_task
    )
    |> Enum.reduce(%{}, fn
      {:ok, {bibcode, result}}, acc -> Map.put(acc, bibcode, result)
      {:exit, _}, acc -> acc
    end)
  end

  @doc """
  Run an arbitrary function over a list of items concurrently,
  returning `{item, result}` pairs.

  This is the low-level building block used by the other functions in this module.

  ## Example

      ADSABSClient.Async.map(bibcodes, fn bibcode ->
        ADSABSClient.Resolver.resolve(bibcode, :preprint)
      end, max_concurrency: 5)
  """
  @spec map([term()], (term() -> term()), keyword()) :: [{term(), term()}]
  def map(items, fun, opts \\ []) when is_list(items) and is_function(fun, 1) do
    max_concurrency = Keyword.get(opts, :max_concurrency, @default_concurrency)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    stream =
      Task.async_stream(
        items,
        fun,
        max_concurrency: max_concurrency,
        timeout: timeout,
        on_timeout: :kill_task
      )

    results =
      Enum.map(stream, fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, Error.network_error(:timeout)}
        {:exit, reason} -> {:error, Error.network_error(reason)}
      end)

    Enum.zip(items, results)
  end

  # --- Private ---

  defp split_opts(opts) do
    async_keys = [:max_concurrency, :timeout]
    async_opts = Keyword.take(opts, async_keys)
    rest_opts = Keyword.drop(opts, async_keys)
    {async_opts, rest_opts}
  end
end
