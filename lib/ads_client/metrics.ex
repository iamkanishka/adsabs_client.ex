defmodule AdsClient.Metrics do
  @moduledoc """
  Metrics API for bibliometric indicators.
  """

  alias AdsClient.{HTTP, Error}
  alias AdsClient.Metrics.Result

  @spec metrics(list(String.t()), keyword()) ::
          {:ok, Result.t()} | {:error, Error.t()}
  def metrics(bibcodes, opts \\ []) when is_list(bibcodes) do
    body = %{
      "bibcodes" => bibcodes,
      "types" => Keyword.get(opts, :types, ["basic", "citations", "indicators"])
    }

    case HTTP.post("/metrics", body: body) do
      {:ok, %{body: response}} -> {:ok, Result.from_api(response)}
      {:error, _} = error -> error
    end
  end

  @spec metrics!(list(String.t()), keyword()) :: Result.t()
  def metrics!(bibcodes, opts \\ []) do
    case metrics(bibcodes, opts) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end
end

defmodule AdsClient.Metrics.Result do
  @moduledoc """
  Metrics result struct.
  """

  @type t :: %__MODULE__{
          citation_count: integer(),
          refereed_citation_count: integer(),
          h_index: integer(),
          i10_index: integer(),
          m_index: float(),
          g_index: integer(),
          read_count: integer(),
          total_number_of_reads: integer(),
          average_number_of_reads: float(),
          median_number_of_reads: float(),
          total_number_of_downloads: integer(),
          average_number_of_downloads: float(),
          median_number_of_downloads: float()
        }

  defstruct [
    :citation_count,
    :refereed_citation_count,
    :h_index,
    :i10_index,
    :m_index,
    :g_index,
    :read_count,
    :total_number_of_reads,
    :average_number_of_reads,
    :median_number_of_reads,
    :total_number_of_downloads,
    :average_number_of_downloads,
    :median_number_of_downloads
  ]

  def from_api(response) do
    struct(__MODULE__, atomize_keys(response))
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
