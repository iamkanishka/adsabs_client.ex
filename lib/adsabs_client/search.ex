defmodule ADSABSClient.Search do
  @moduledoc """
  ADS Search API — `/search/query` and `/search/bigquery`.

  Supports full Solr query syntax, faceting, highlighting, cursor pagination,
  and lazy `Stream`-based result iteration.

  ## Quick Start

      # Simple query string
      {:ok, response} = ADSABSClient.Search.query("black holes year:2020")

      # Using the Query builder
      alias ADSABSClient.Query

      {:ok, resp} =
        Query.new()
        |> Query.author("Hawking, S")
        |> Query.year_range(1970, 2018)
        |> Query.property(:refereed)
        |> Query.fields(["title", "bibcode", "citation_count", "year"])
        |> Query.sort("citation_count", :desc)
        |> Query.rows(20)
        |> ADSABSClient.Search.query()

      resp.num_found   # => 142
      hd(resp.docs)    # => %{"title" => [...], "bibcode" => "...", ...}

  ## Lazy Streaming (large result sets)

      # Lazily fetch all refereed papers by an author
      ADSABSClient.Search.stream("author:\\"Zwicky, F\\" property:refereed")
      |> Stream.filter(&(&1["citation_count"] > 50))
      |> Enum.take(100)

  ## Bigquery (large bibcode sets)

      bibcodes = ["2019ApJ...882L..24A", "2020A&A...641A...1P"]
      {:ok, resp} = ADSABSClient.Search.bigquery(bibcodes, fields: ["title", "citation_count"])
  """

  alias ADSABSClient.{Error, HTTP, Query, RateLimitInfo}
  alias ADSABSClient.Search.Response

  @search_path "/search/query"
  @bigquery_path "/search/bigquery"

  @type query_opt ::
          {:fields, [String.t()]}
          | {:sort, String.t()}
          | {:rows, pos_integer()}
          | {:start, non_neg_integer()}
          | {:highlight, boolean()}
          | {:facets, [String.t()]}
          | {:params, map()}

  @doc """
  Execute a search query against the ADS Search API.

  Accepts either a raw Solr query string or an `ADSABSClient.Query` struct.

  ## Options

  - `:fields` — list of fields to return (default: `["bibcode", "title", "author", "year"]`)
  - `:sort` — sort expression e.g. `"citation_count desc"` (default: `"score desc"`)
  - `:rows` — results per page, max 2000 (default: `10`)
  - `:start` — offset for pagination (default: `0`)
  - `:highlight` — enable text highlighting (default: `false`)
  - `:facets` — list of fields to facet on
  - `:params` — raw additional params merged into the request

  ## Examples

      {:ok, resp} = ADSABSClient.Search.query("star formation", rows: 5, fields: ["title"])
      {:ok, resp} = ADSABSClient.Search.query(my_query_struct)
  """
  @spec query(String.t() | Query.t(), [query_opt()]) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def query(q, opts \\ [])

  def query(%Query{} = q, opts) do
    params = Map.merge(Query.to_params(q), build_extra_params(opts))
    do_search(@search_path, params)
  end

  def query(q_string, opts) when is_binary(q_string) do
    params =
      %{
        "q" => q_string,
        "fl" => Enum.join(Keyword.get(opts, :fields, default_fields()), ","),
        "rows" => Keyword.get(opts, :rows, 10),
        "start" => Keyword.get(opts, :start, 0)
      }
      |> maybe_put("sort", opts[:sort])
      |> maybe_put("hl", opts[:highlight] && "true")
      |> Map.merge(Keyword.get(opts, :params, %{}))

    do_search(@search_path, params)
  end

  @doc """
  Search for a set of bibcodes via the `/search/bigquery` endpoint.

  Useful when you have a large list of bibcodes (up to ~2000 per request).

  ## Example

      bibcodes = ["2019ApJ...882L..24A", "2020A&A...641A...1P"]
      {:ok, resp} = ADSABSClient.Search.bigquery(bibcodes, fields: ["title", "abstract"])
  """
  @spec bigquery([String.t()], [query_opt()]) :: {:ok, Response.t()} | {:error, Error.t()}
  def bigquery(bibcodes, opts \\ []) when is_list(bibcodes) do
    if Enum.empty?(bibcodes) do
      {:error, Error.validation_error("bigquery requires at least one bibcode")}
    else
      # ADS bigquery expects a plain-text body: "bibcode\n<code1>\n<code2>..."
      # with standard search params in the query string
      body_text = "bibcode\n" <> Enum.join(bibcodes, "\n")

      params = %{
        "q" => "*:*",
        "fl" => Enum.join(Keyword.get(opts, :fields, default_fields()), ","),
        "rows" => Keyword.get(opts, :rows, min(length(bibcodes), 2000)),
        "start" => Keyword.get(opts, :start, 0)
      }

      with {:ok, resp} <-
             HTTP.client().post(@bigquery_path, body_text,
               params: params,
               content_type: "big-query/csv"
             ) do
        rate_info = extract_rate_info(resp)
        {:ok, Response.from_response(resp.body, rate_info)}
      end
    end
  end

  @doc """
  Find papers that cite the given bibcodes.

  ## Example

      {:ok, resp} = ADSABSClient.Search.citations(["2016PhRvL.116f1102A"])
  """
  @spec citations([String.t()], [query_opt()]) :: {:ok, Response.t()} | {:error, Error.t()}
  def citations(bibcodes, opts \\ []) when is_list(bibcodes) do
    refs = Enum.map_join(bibcodes, " OR ", &"citations(#{&1})")
    query(refs, opts)
  end

  @doc """
  Find papers referenced by the given bibcodes.

  ## Example

      {:ok, resp} = ADSABSClient.Search.references(["2016PhRvL.116f1102A"])
  """
  @spec references([String.t()], [query_opt()]) :: {:ok, Response.t()} | {:error, Error.t()}
  def references(bibcodes, opts \\ []) when is_list(bibcodes) do
    refs = Enum.map_join(bibcodes, " OR ", &"references(#{&1})")
    query(refs, opts)
  end

  @doc """
  Find trending papers related to a query.

  Uses the ADS `trending()` special operator to surface papers recently
  read by people who searched for this query.
  """
  @spec trending(String.t(), [query_opt()]) :: {:ok, Response.t()} | {:error, Error.t()}
  def trending(q_string, opts \\ []) when is_binary(q_string) do
    query("trending(#{q_string})", opts)
  end

  @doc """
  Lazily stream all search results as an Elixir `Stream`.

  Internally uses cursor-based pagination so it works for result sets of any size.
  Pages are fetched on demand as the stream is consumed.

  ## Example

      # Fetch all papers, take first 500 with >100 citations
      ADSABSClient.Search.stream("black hole formation")
      |> Stream.filter(&((&1["citation_count"] || 0) > 100))
      |> Enum.take(500)

  ## Options

  Same as `query/2`. `:rows` controls the page size (default: 200).
  """
  @spec stream(String.t() | Query.t(), [query_opt()]) :: Enumerable.t()
  def stream(q, opts \\ []) do
    page_size = Keyword.get(opts, :rows, 200)
    base_opts = Keyword.put(opts, :rows, page_size)

    Stream.resource(
      fn -> {:cursor, "*"} end,
      fn
        :done ->
          {:halt, :done}

        {:cursor, cursor_mark} ->
          # Thread cursor into both Query structs and string queries
          {q_with_cursor, page_opts} = apply_cursor_to(q, cursor_mark, base_opts)

          case query(q_with_cursor, page_opts) do
            {:ok, %{docs: []}} ->
              {[], :done}

            {:ok, %{docs: docs, next_cursor_mark: next}} when next == cursor_mark ->
              # Cursor didn't advance — last page reached
              {docs, :done}

            {:ok, %{docs: docs, next_cursor_mark: nil}} ->
              {docs, :done}

            {:ok, %{docs: docs, next_cursor_mark: next}} ->
              {docs, {:cursor, next}}

            {:error, error} ->
              raise "ADSABSClient.Search.stream failed: #{inspect(error)}"
          end
      end,
      fn _ -> :ok end
    )
  end

  # --- Private helpers ---

  defp do_search(path, params) do
    with {:ok, resp} <- HTTP.client().get(path, params: params) do
      rate_info = extract_rate_info(resp)
      {:ok, Response.from_response(resp.body, rate_info)}
    end
  end

  defp extract_rate_info(%{headers: headers}) do
    RateLimitInfo.from_headers(headers)
  end

  defp build_extra_params(opts) do
    Keyword.get(opts, :params, %{})
  end

  defp apply_cursor_to(%Query{} = q, cursor_mark, opts) do
    {Query.cursor(q, cursor_mark), opts}
  end

  defp apply_cursor_to(q_string, cursor_mark, opts) when is_binary(q_string) do
    # For string queries, inject cursorMark via the :params option
    extra = Map.merge(Keyword.get(opts, :params, %{}), %{"cursorMark" => cursor_mark})
    {q_string, Keyword.put(opts, :params, extra)}
  end

  defp default_fields, do: ["bibcode", "title", "author", "year", "abstract"]

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, false), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
