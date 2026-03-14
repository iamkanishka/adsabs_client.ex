defmodule ADSABSClient.Search.Response do
  @moduledoc """
  Typed struct for ADS Search API responses.

  ## Fields

  - `:num_found` — total number of matching documents
  - `:start` — offset of the first returned document
  - `:docs` — list of document maps (fields depend on query `fl` parameter)
  - `:facets` — parsed facet counts (if facets were requested)
  - `:highlights` — per-document text highlights (if `hl=true` was set)
  - `:next_cursor_mark` — opaque string for the next page (cursor pagination)
  - `:qtime` — server-side query time in milliseconds
  - `:rate_limit` — `RateLimitInfo` parsed from response headers
  """

  alias ADSABSClient.RateLimitInfo

  @type doc :: map()

  @type t :: %__MODULE__{
          num_found: non_neg_integer(),
          start: non_neg_integer(),
          docs: [doc()],
          facets: map(),
          highlights: map(),
          next_cursor_mark: String.t() | nil,
          qtime: non_neg_integer() | nil,
          rate_limit: RateLimitInfo.t()
        }

  defstruct num_found: 0,
            start: 0,
            docs: [],
            facets: %{},
            highlights: %{},
            next_cursor_mark: nil,
            qtime: nil,
            rate_limit: %RateLimitInfo{}

  @doc "Build a Response from a raw ADS API response map."
  @spec from_response(map(), RateLimitInfo.t()) :: t()
  def from_response(body, rate_limit \\ %RateLimitInfo{}) do
    response = Map.get(body, "response", %{})
    facet_counts = Map.get(body, "facet_counts", %{})
    highlighting = Map.get(body, "highlighting", %{})

    %__MODULE__{
      num_found: Map.get(response, "numFound", 0),
      start: Map.get(response, "start", 0),
      docs: Map.get(response, "docs", []),
      facets: parse_facets(facet_counts),
      highlights: highlighting,
      next_cursor_mark: Map.get(body, "nextCursorMark"),
      qtime: get_in(body, ["responseHeader", "QTime"]),
      rate_limit: rate_limit
    }
  end

  defp parse_facets(%{"facet_fields" => fields}) do
    Map.new(fields, fn {field, counts} ->
      pairs =
        counts
        |> Enum.chunk_every(2)
        |> Enum.map(fn [term, count] -> {term, count} end)

      {field, pairs}
    end)
  end

  defp parse_facets(_), do: %{}
end
