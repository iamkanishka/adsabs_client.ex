defmodule AdsClient.Search do
  @moduledoc """
  Search functionality for ADS API.
  """

  alias AdsClient.{HTTP, SearchResult, Error}

  @default_rows 10
  @max_rows 2000

  @spec search(String.t(), keyword()) ::
    {:ok, SearchResult.t()} | {:error, Error.t()}
  def search(query, opts \\ []) do
    params = build_params(query, opts)

    case HTTP.get("/search/query", query: params) do
      {:ok, %{body: body}} ->
        {:ok, SearchResult.from_api(body)}
      {:error, _} = error ->
        error
    end
  end

  @spec search!(String.t(), keyword()) :: SearchResult.t()
  def search!(query, opts \\ []) do
    case search(query, opts) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @spec stream_search(String.t(), keyword()) :: Enumerable.t()
  def stream_search(query, opts \\ []) do
    rows = Keyword.get(opts, :rows, 100)

    Stream.resource(
      fn -> {0, true} end,
      fn {start, more?} = state ->
        if more? do
          case search(query, Keyword.merge(opts, [rows: rows, start: start])) do
            {:ok, %SearchResult{docs: docs, num_found: num_found}} ->
              next_start = start + rows
              has_more = next_start < num_found
              {docs, {next_start, has_more}}

            {:error, error} ->
              raise error
          end
        else
          {:halt, state}
        end
      end,
      fn _ -> :ok end
    )
  end

  @spec bigquery(list(String.t()), keyword()) ::
    {:ok, SearchResult.t()} | {:error, Error.t()}
  def bigquery(bibcodes, opts \\ []) when is_list(bibcodes) do
    if length(bibcodes) > 2000 do
      {:error, Error.new(:validation, "bigquery supports max 2000 bibcodes")}
    else
      body = %{
        "bibcode" => bibcodes,
        "q" => Keyword.get(opts, :q, "*:*"),
        "fl" => Keyword.get(opts, :fl, "bibcode,title,author")
      }

      case HTTP.post("/search/bigquery", body: body) do
        {:ok, %{body: response}} ->
          {:ok, SearchResult.from_api(response)}
        {:error, _} = error ->
          error
      end
    end
  end

  defp build_params(query, opts) do
    %{
      "q" => query,
      "rows" => min(Keyword.get(opts, :rows, @default_rows), @max_rows),
      "start" => Keyword.get(opts, :start, 0)
    }
    |> add_optional_param("sort", opts[:sort])
    |> add_optional_param("fl", format_fl(opts[:fl]))
    |> add_optional_param("fq", opts[:fq])
  end

  defp add_optional_param(params, _key, nil), do: params
  defp add_optional_param(params, key, value), do: Map.put(params, key, value)

  defp format_fl(nil), do: nil
  defp format_fl(fields) when is_list(fields) do
    Enum.map_join(fields, ",", &to_string/1)
  end
  defp format_fl(fields) when is_binary(fields), do: fields
end
