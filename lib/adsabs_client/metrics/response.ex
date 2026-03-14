defmodule ADSABSClient.Metrics.Response do
  @moduledoc """
  Typed struct for ADS Metrics API responses.
  """

  @type t :: %__MODULE__{
          basic_stats: map(),
          citation_stats: map(),
          histograms: map(),
          indicators: map(),
          timeseries: map(),
          skipped_bibcodes: [String.t()]
        }

  defstruct basic_stats: %{},
            citation_stats: %{},
            histograms: %{},
            indicators: %{},
            timeseries: %{},
            skipped_bibcodes: []

  @doc "Build a Response from the raw ADS Metrics API body."
  @spec from_response(map()) :: t()
  def from_response(body) when is_map(body) do
    %__MODULE__{
      basic_stats: Map.get(body, "basic stats", %{}),
      citation_stats: Map.get(body, "citation stats", %{}),
      histograms: Map.get(body, "histograms", %{}),
      indicators: Map.get(body, "indicators", %{}),
      timeseries: Map.get(body, "time series", %{}),
      skipped_bibcodes: Map.get(body, "skipped bibcodes", [])
    }
  end
end
