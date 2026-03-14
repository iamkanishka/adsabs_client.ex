defmodule ADSABSClient.CitationHelper do
  @moduledoc """
  ADS Citation Helper API — `/citation_helper`.

  Suggests missing references for a paper based on its existing reference list.
  Useful for finding papers that are frequently cited alongside your references
  but that you may have missed.

  ## Example

      # Find suggested missing references
      {:ok, suggestions} = ADSABSClient.CitationHelper.suggest(
        references: ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"],
        title: "My Paper About Gravitational Waves"
      )
      # suggestions["results"] => list of recommended bibcodes with scores
  """

  alias ADSABSClient.{Error, HTTP}

  @doc """
  Suggest missing references for a paper.

  ## Options

  - `:references` — list of bibcodes already in the paper's reference list
  - `:title` — paper title (improves suggestions)
  - `:abstract` — paper abstract (improves suggestions)

  ## Example

      {:ok, result} = ADSABSClient.CitationHelper.suggest(
        references: ["2016PhRvL.116f1102A"],
        title: "Gravitational wave follow-up observations"
      )

      result["results"]
      |> Enum.take(5)
      |> Enum.each(fn r -> IO.puts(r["bibcode"]) end)
  """
  @spec suggest(keyword()) :: {:ok, map()} | {:error, ADSABSClient.Error.t()}
  def suggest(opts \\ []) do
    references = Keyword.get(opts, :references, [])

    if Enum.empty?(references) do
      {:error, Error.validation_error("suggest requires at least one reference bibcode")}
    else
      body =
        %{"bibcodes" => references}
        |> maybe_put("title", opts[:title])
        |> maybe_put("abstract", opts[:abstract])

      with {:ok, resp} <- HTTP.client().post("/citation_helper", body, []) do
        {:ok, resp.body}
      end
    end
  end

  # --- Private ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
