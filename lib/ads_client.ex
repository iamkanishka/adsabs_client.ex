defmodule AdsClient do
  @moduledoc """
  Elixir client for NASA Astrophysics Data System (ADS) API.

  ## Configuration

  Configure in `config/runtime.exs`:

      config :ads_client,
        api_token: System.get_env("ADS_API_TOKEN"),
        adapter: AdsClient.Adapter.Req,
        base_url: "https://api.adsabs.harvard.edu/v1",
        default_timeout: 30_000,
        max_retries: 3

  ## Usage

      # Basic search
      {:ok, results} = AdsClient.search("black holes")

      # Advanced search with options
      {:ok, results} = AdsClient.search(
        "author:Einstein year:1905",
        rows: 100,
        sort: "citation_count desc"
      )

      # Stream large result sets
      AdsClient.stream_search("galaxy formation", rows: 50)
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()

      # Get metrics
      {:ok, metrics} = AdsClient.metrics(["2020ApJ...123..456A"])

      # Export citations
      {:ok, bibtex} = AdsClient.export(["2020ApJ...123..456A"], :bibtex)

  ## Error Handling

  All functions return `{:ok, result}` or `{:error, %AdsClient.Error{}}`.
  Bang variants (`search!/2`, `metrics!/1`) raise on error.

      case AdsClient.search("neutron stars") do
        {:ok, results} -> process_results(results)
        {:error, %AdsClient.Error{type: :rate_limit}} -> schedule_retry()
        {:error, error} -> log_error(error)
      end

  ## Observability

  The client emits telemetry events for monitoring:

      :telemetry.attach(
        "ads-request-logger",
        [:ads_client, :request, :stop],
        &handle_event/4,
        nil
      )
  """

  alias AdsClient.{Search, Metrics, Export, Libraries, Resolver}

  @doc """
  Search the ADS database.

  ## Parameters

    * `query` - Solr query string
    * `opts` - Keyword list of options:
      * `:rows` - Number of results per page (default: 10, max: 2000)
      * `:start` - Starting row (default: 0)
      * `:sort` - Sort field and direction (e.g., "citation_count desc")
      * `:fl` - Fields to return (list of atoms or strings)
      * `:fq` - Filter queries (list of strings)

  ## Examples

      iex> AdsClient.search("author:Einstein year:1905")
      {:ok, %AdsClient.SearchResult{}}

      iex> AdsClient.search("dark matter", rows: 50, sort: "date desc")
      {:ok, %AdsClient.SearchResult{}}
  """
  @spec search(String.t(), keyword()) ::
    {:ok, AdsClient.SearchResult.t()} | {:error, AdsClient.Error.t()}
  defdelegate search(query, opts \\ []), to: Search

  @doc """
  Search with raised exceptions on error.
  """
  @spec search!(String.t(), keyword()) :: AdsClient.SearchResult.t()
  defdelegate search!(query, opts \\ []), to: Search

  @doc """
  Stream search results lazily, fetching pages as needed.

  ## Examples

      AdsClient.stream_search("exoplanets", rows: 100)
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream_search(String.t(), keyword()) :: Enumerable.t()
  defdelegate stream_search(query, opts \\ []), to: Search

  @doc """
  Get metrics for a list of bibcodes.

  ## Examples

      iex> AdsClient.metrics(["2020ApJ...123..456A"])
      {:ok, %AdsClient.Metrics.Result{}}
  """
  @spec metrics(list(String.t()), keyword()) ::
    {:ok, AdsClient.Metrics.Result.t()} | {:error, AdsClient.Error.t()}
  defdelegate metrics(bibcodes, opts \\ []), to: Metrics

  @doc """
  Get metrics with raised exceptions on error.
  """
  @spec metrics!(list(String.t()), keyword()) :: AdsClient.Metrics.Result.t()
  defdelegate metrics!(bibcodes, opts \\ []), to: Metrics

  @doc """
  Export bibcodes in various formats.

  ## Formats

    * `:bibtex` - BibTeX format
    * `:bibtexabs` - BibTeX with abstracts
    * `:endnote` - EndNote format
    * `:aastex` - AASTeX format
    * `:ris` - RIS format
    * And 20+ more formats

  ## Examples

      iex> AdsClient.export(["2020ApJ...123..456A"], :bibtex)
      {:ok, "@ARTICLE{...}"}
  """
  @spec export(list(String.t()), atom(), keyword()) ::
    {:ok, String.t()} | {:error, AdsClient.Error.t()}
  defdelegate export(bibcodes, format, opts \\ []), to: Export

  @doc """
  Export with raised exceptions on error.
  """
  @spec export!(list(String.t()), atom(), keyword()) :: String.t()
  defdelegate export!(bibcodes, format, opts \\ []), to: Export

  @doc """
  List all libraries for the authenticated user.
  """
  @spec list_libraries(keyword()) ::
    {:ok, list(AdsClient.Library.t())} | {:error, AdsClient.Error.t()}
  defdelegate list_libraries(opts \\ []), to: Libraries

  @doc """
  Get a specific library by ID.
  """
  @spec get_library(String.t(), keyword()) ::
    {:ok, AdsClient.Library.t()} | {:error, AdsClient.Error.t()}
  defdelegate get_library(library_id, opts \\ []), to: Libraries

  @doc """
  Create a new library.
  """
  @spec create_library(String.t(), String.t(), keyword()) ::
    {:ok, AdsClient.Library.t()} | {:error, AdsClient.Error.t()}
  defdelegate create_library(name, description, opts \\ []), to: Libraries

  @doc """
  Resolve links for a bibcode.
  """
  @spec resolve(String.t(), atom() | nil, keyword()) ::
    {:ok, map()} | {:error, AdsClient.Error.t()}
  defdelegate resolve(bibcode, link_type \\ nil, opts \\ []), to: Resolver
end
