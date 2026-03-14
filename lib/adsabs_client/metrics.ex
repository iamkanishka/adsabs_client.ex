defmodule ADSABSClient.Metrics do
  @moduledoc """
  ADS Metrics API — `/metrics`.

  Computes citation and usage statistics for a set of papers.

  ## Available Metric Types

  | Type | Description |
  |---|---|
  | `:all` | All metrics (default) |
  | `:basic` | Basic counts (papers, citations, reads) |
  | `:citations` | Citation histograms and normalized counts |
  | `:indicators` | Bibliometric indicators (h-index, g-index, tori, etc.) |
  | `:histograms` | Year-by-year histogram data |
  | `:timeseries` | Time-series citation/read data |

  ## Examples

      bibcodes = ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

      # All metrics
      {:ok, metrics} = ADSABSClient.Metrics.fetch(bibcodes)
      metrics.indicators["h"] # => 12

      # Only citation stats
      {:ok, metrics} = ADSABSClient.Metrics.citations(bibcodes)

      # Only indicators
      {:ok, metrics} = ADSABSClient.Metrics.indicators(bibcodes)
  """

  alias ADSABSClient.{Error, HTTP}
  alias ADSABSClient.Metrics.Response

  @type bibcodes :: [String.t()]
  @type metrics_result :: {:ok, Response.t()} | {:error, Error.t()}

  @doc """
  Fetch all available metrics for a list of bibcodes.

  ## Example

      {:ok, resp} = ADSABSClient.Metrics.fetch(["2016PhRvL.116f1102A"])
      resp.indicators["h"]       # h-index
      resp.citation_stats        # citation summary
  """
  @spec fetch(bibcodes(), keyword()) :: metrics_result()
  def fetch(bibcodes, opts \\ []) do
    request(bibcodes, :all, opts)
  end

  @doc "Fetch only basic counts (paper count, citation count, read count)."
  @spec basic(bibcodes(), keyword()) :: metrics_result()
  def basic(bibcodes, opts \\ []) do
    request(bibcodes, :basic, opts)
  end

  @doc "Fetch citation statistics and histograms."
  @spec citations(bibcodes(), keyword()) :: metrics_result()
  def citations(bibcodes, opts \\ []) do
    request(bibcodes, :citations, opts)
  end

  @doc """
  Fetch bibliometric indicators: h-index, g-index, m-index, i10-index,
  tori (time-normalized), riq, and read10.
  """
  @spec indicators(bibcodes(), keyword()) :: metrics_result()
  def indicators(bibcodes, opts \\ []) do
    request(bibcodes, :indicators, opts)
  end

  @doc "Fetch year-by-year histogram data."
  @spec histograms(bibcodes(), keyword()) :: metrics_result()
  def histograms(bibcodes, opts \\ []) do
    request(bibcodes, :histograms, opts)
  end

  @doc "Fetch time-series citation and read data."
  @spec timeseries(bibcodes(), keyword()) :: metrics_result()
  def timeseries(bibcodes, opts \\ []) do
    request(bibcodes, :timeseries, opts)
  end

  # --- Private ---

  defp request(bibcodes, type, _opts) when is_list(bibcodes) do
    if Enum.empty?(bibcodes) do
      {:error, Error.validation_error("metrics requires at least one bibcode")}
    else
      body = build_body(bibcodes, type)

      with {:ok, resp} <- HTTP.client().post("/metrics", body, []) do
        {:ok, Response.from_response(resp.body)}
      end
    end
  end

  defp build_body(bibcodes, :all) do
    %{"bibcodes" => bibcodes}
  end

  defp build_body(bibcodes, type) do
    %{"bibcodes" => bibcodes, "types" => [to_string(type)]}
  end
end
