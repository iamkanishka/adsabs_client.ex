defmodule ADSABSClient.Pagination do
  @moduledoc """
  Pagination helpers for ADS Search API results.

  The ADS API supports two pagination strategies:

  1. **Offset pagination** (`start` + `rows`) — simple but limited to ~10,000 results
  2. **Cursor pagination** (`cursorMark`) — deep pagination for any number of results

  This module provides utilities for both, and is used internally by
  `ADSABSClient.Search.stream/2`.

  ## Offset Pagination

      alias ADSABSClient.{Pagination, Search}

      # Manually paginate with start/rows
      {:ok, page1} = Search.query("black holes", rows: 100, start: 0)
      {:ok, page2} = Search.query("black holes", rows: 100, start: 100)

      # Or use the helper
      pages = Pagination.pages("black holes", rows: 100)
      # => Stream of %Search.Response{} structs

  ## Cursor Pagination (recommended for large sets)

      # Collect all results into a list (careful with memory for huge sets)
      all = Pagination.collect_all("author:\\"Einstein\\"")

      # Or stream lazily
      ADSABSClient.Search.stream("author:\\"Einstein\\"")
      |> Enum.take(1000)
  """

  alias ADSABSClient.{Error, Search}
  alias ADSABSClient.Search.Response

  @max_offset_rows 10_000

  @doc """
  Return a `Stream` of `%Search.Response{}` page structs for a query.

  Each element in the stream is one full page (not one document).
  Use `ADSABSClient.Search.stream/2` if you want individual documents.

  ## Options

  - `:rows` — results per page (default: 200)
  - `:max_results` — stop after this many total results (default: unlimited)
  - All `Search.query/2` options are forwarded

  ## Example

      Pagination.pages("black holes", rows: 100)
      |> Enum.each(fn page ->
        IO.puts("Got \#{length(page.docs)} docs")
      end)
  """
  @spec pages(String.t() | ADSABSClient.Query.t(), keyword()) :: Enumerable.t()
  def pages(query, opts \\ []) do
    rows = Keyword.get(opts, :rows, 200)
    max_results = Keyword.get(opts, :max_results, :infinity)

    Stream.resource(
      fn -> {:cursor, "*", 0} end,
      fn
        :done ->
          {:halt, :done}

        {:cursor, cursor_mark, fetched} ->
          if max_results != :infinity and fetched >= max_results do
            {:halt, :done}
          else
            q_with_cursor = put_cursor(query, cursor_mark)
            merged_opts = merge_cursor_opts(query, cursor_mark, Keyword.merge(opts, rows: rows))

            case Search.query(q_with_cursor, merged_opts) do
              {:ok, %Response{docs: [], next_cursor_mark: _}} ->
                {[], :done}

              {:ok, %Response{next_cursor_mark: ^cursor_mark} = page} ->
                # Cursor didn't advance — last page
                {[page], :done}

              {:ok, %Response{docs: docs, next_cursor_mark: next} = page} ->
                {[page], {:cursor, next, fetched + length(docs)}}

              {:error, error} ->
                raise "ADSABSClient.Pagination.pages/2 failed: #{inspect(error)}"
            end
          end
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Collect all documents matching a query into a list.

  **Warning**: This loads all results into memory. For queries returning
  millions of papers, use `ADSABSClient.Search.stream/2` with `Enum.take/2`
  or `Stream.take/2` instead.

  ## Options

  Same as `pages/2`. `:max_results` is strongly recommended.

  ## Example

      # Get all refereed papers by an author (up to 5000)
      papers = Pagination.collect_all(
        ~s(author:"Hawking, S" property:refereed),
        max_results: 5000,
        rows: 200
      )
      length(papers)  # => 142
  """
  @spec collect_all(String.t() | ADSABSClient.Query.t(), keyword()) :: [map()]
  def collect_all(query, opts \\ []) do
    query
    |> pages(opts)
    |> Enum.flat_map(& &1.docs)
  end

  @doc """
  Returns the total number of results for a query without fetching any documents.

  Makes a single API request with `rows=0`.

  ## Example

      {:ok, count} = Pagination.count("black holes property:refereed")
      # => {:ok, 45_320}
  """
  @spec count(String.t() | ADSABSClient.Query.t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def count(query) do
    opts = [rows: 0, fields: ["id"]]

    case Search.query(query, opts) do
      {:ok, %Response{num_found: n}} -> {:ok, n}
      {:error, _} = err -> err
    end
  end

  @doc """
  Check whether cursor pagination should be used for a given result count.

  Returns `true` if the result count exceeds the offset pagination limit (10,000).
  """
  @spec needs_cursor?(non_neg_integer()) :: boolean()
  def needs_cursor?(num_found), do: num_found > @max_offset_rows

  # --- Private ---

  # For Query structs, embed cursor directly in the struct.
  defp put_cursor(%ADSABSClient.Query{} = q, cursor), do: ADSABSClient.Query.cursor(q, cursor)
  # For string queries, the query itself is unchanged; cursor travels in opts[:params].
  defp put_cursor(q_string, _cursor) when is_binary(q_string), do: q_string

  # For string queries, inject cursorMark into params so Search.query/2 forwards it.
  defp merge_cursor_opts(q_string, cursor_mark, opts) when is_binary(q_string) do
    extra = %{"cursorMark" => cursor_mark}
    current = Keyword.get(opts, :params, %{})
    Keyword.put(opts, :params, Map.merge(current, extra))
  end

  # For Query structs, cursor is already embedded; no opts change needed.
  defp merge_cursor_opts(%ADSABSClient.Query{}, _cursor_mark, opts), do: opts
end
