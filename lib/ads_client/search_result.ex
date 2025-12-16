defmodule AdsabsClient.SearchResult do
  @moduledoc """
  Search result struct.
  """

  @type t :: %__MODULE__{
    num_found: integer(),
    start: integer(),
    docs: list(map()),
    facets: map(),
    highlights: map()
  }

  defstruct [:num_found, :start, :docs, :facets, :highlights]

  def from_api(response) do
    %__MODULE__{
      num_found: get_in(response, ["response", "numFound"]) || 0,
      start: get_in(response, ["response", "start"]) || 0,
      docs: get_in(response, ["response", "docs"]) || [],
      facets: response["facets"],
      highlights: response["highlighting"]
    }
  end
end
