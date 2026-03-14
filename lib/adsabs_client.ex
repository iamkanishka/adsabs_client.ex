defmodule ADSABSClient do
  @moduledoc """
  A fully-featured Elixir client for the SAO/NASA Astrophysics Data System (ADS) API v1.

  ## Installation

  Add to your `mix.exs`:

      def deps do
        [{:adsabs_client, "~> 0.2"}]
      end

  ## Configuration

      # config/config.exs
      config :adsabs_client,
        api_token: System.get_env("ADS_API_TOKEN"),
        # optional overrides:
        base_url: "https://api.adsabs.harvard.edu/v1",
        receive_timeout: 30_000,
        max_retries: 3

  Get your API token at https://ui.adsabs.harvard.edu/user/settings/token

  ## Quick Start

      # Search for papers
      {:ok, resp} = ADSABSClient.Search.query("black holes", rows: 5)
      resp.num_found  # => 12_345

      # Use the query builder
      alias ADSABSClient.Query

      {:ok, resp} =
        Query.new()
        |> Query.author("Hawking, S")
        |> Query.year_range(1970, 2018)
        |> Query.property(:refereed)
        |> Query.fields(["title", "bibcode", "citation_count"])
        |> Query.sort("citation_count", :desc)
        |> ADSABSClient.Search.query()

      # Export to BibTeX
      bibcodes = Enum.map(resp.docs, & &1["bibcode"])
      {:ok, bibtex} = ADSABSClient.Export.bibtex(bibcodes)

      # Get citation metrics
      {:ok, metrics} = ADSABSClient.Metrics.fetch(bibcodes)
      metrics.indicators["h"]  # h-index

      # Stream all results (lazy pagination)
      ADSABSClient.Search.stream("gravitational waves")
      |> Stream.filter(&((&1["citation_count"] || 0) > 50))
      |> Enum.take(100)

  ## Modules

  | Module | Description |
  |---|---|
  | `ADSABSClient.Search` | Full-text and fielded paper search |
  | `ADSABSClient.Export` | BibTeX, RIS, EndNote, and custom export |
  | `ADSABSClient.Metrics` | Citation counts, h-index, time series |
  | `ADSABSClient.Libraries` | CRUD for private paper collections |
  | `ADSABSClient.Journals` | Journal metadata and holdings |
  | `ADSABSClient.Resolver` | Resolve bibcodes to full-text links |
  | `ADSABSClient.Objects` | Astronomical object name resolution |
  | `ADSABSClient.Oracle` | Paper recommendations and matching |
  | `ADSABSClient.Vis` | Network and word-cloud visualization data |
  | `ADSABSClient.Accounts` | Token validation and rate limit status |
  | `ADSABSClient.CitationHelper` | Suggest missing references |
  | `ADSABSClient.Feedback` | Submit record feedback to ADS |
  | `ADSABSClient.Query` | Composable Solr query builder DSL |
  | `ADSABSClient.Pagination` | Page-level helpers and `collect_all/2` |
  | `ADSABSClient.Async` | Concurrent batch request helpers |
  | `ADSABSClient.RateLimiter` | GenServer tracking global rate-limit state |
  | `ADSABSClient.Telemetry` | Telemetry events and logging handlers |

  ## Error Handling

  All functions return `{:ok, result}` or `{:error, %ADSABSClient.Error{}}`:

      case ADSABSClient.Search.query("stars") do
        {:ok, resp} ->
          Enum.each(resp.docs, &IO.puts(&1["title"]))
        {:error, %ADSABSClient.Error{type: :rate_limited, retry_after: secs}} ->
          :timer.sleep(secs * 1_000)
        {:error, %ADSABSClient.Error{type: :unauthorized}} ->
          raise "Invalid API token — check ADS_API_TOKEN"
        {:error, error} ->
          Logger.error("Search failed: \#{error.message}")
      end
  """

  # Convenience re-exports for the most common operations

  @doc "Delegate to `ADSABSClient.Search.query/2`."
  defdelegate search(query, opts \\ []), to: ADSABSClient.Search, as: :query

  @doc "Delegate to `ADSABSClient.Export.bibtex/2`."
  defdelegate export_bibtex(bibcodes, opts \\ []), to: ADSABSClient.Export, as: :bibtex

  @doc "Delegate to `ADSABSClient.Metrics.fetch/2`."
  defdelegate metrics(bibcodes, opts \\ []), to: ADSABSClient.Metrics, as: :fetch

  @doc "Delegate to `ADSABSClient.Search.stream/2`."
  defdelegate stream(query, opts \\ []), to: ADSABSClient.Search, as: :stream

  @doc "Delegate to `ADSABSClient.Pagination.count/1`."
  defdelegate count(query), to: ADSABSClient.Pagination, as: :count

  @doc "Delegate to `ADSABSClient.Pagination.collect_all/2`."
  defdelegate collect_all(query, opts \\ []), to: ADSABSClient.Pagination, as: :collect_all

  @doc "Delegate to `ADSABSClient.Accounts.status/0`."
  defdelegate status(), to: ADSABSClient.Accounts, as: :status

  @doc "Delegate to `ADSABSClient.Accounts.validate_token/0`."
  defdelegate validate_token(), to: ADSABSClient.Accounts, as: :validate_token
end
