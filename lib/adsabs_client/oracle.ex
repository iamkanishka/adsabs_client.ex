defmodule ADSABSClient.Oracle do
  @moduledoc """
  ADS Oracle API — `/oracle/*`.

  Provides paper recommendations based on reading history
  and document similarity matching.

  ## Examples

      # Find papers similar to ones you've read
      {:ok, recs} = ADSABSClient.Oracle.also_read(["2016PhRvL.116f1102A"])

      # Match a document (e.g. a new draft) to existing ADS records
      {:ok, matches} = ADSABSClient.Oracle.match_document(
        title: "Gravitational wave detection with LIGO",
        abstract: "We report the direct detection...",
        author: ["Abbott, B.P.", "Abbott, R."]
      )
  """

  alias ADSABSClient.{Error, HTTP}

  @doc """
  Find papers frequently read together with the given bibcodes.

  Useful for "readers who read this also read..." recommendations.

  ## Example

      {:ok, result} = ADSABSClient.Oracle.also_read(["2016PhRvL.116f1102A"])
      result["bibcodes"]  # => ["...", ...]
  """
  @spec also_read([String.t()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def also_read(bibcodes, opts \\ []) when is_list(bibcodes) do
    if Enum.empty?(bibcodes) do
      {:error, Error.validation_error("also_read requires at least one bibcode")}
    else
      params =
        %{"bibcodes" => Enum.join(bibcodes, ",")}
        |> maybe_put("rows", opts[:rows])

      with {:ok, resp} <- HTTP.client().get("/oracle/alsoread", params: params) do
        {:ok, resp.body}
      end
    end
  end

  @doc """
  Match a document description (title, abstract, authors) to existing ADS records.

  Useful for linking preprints or drafts to their published counterparts.

  ## Options

  - `:title` — document title (recommended)
  - `:abstract` — document abstract
  - `:author` — list of author names
  - `:year` — publication year
  - `:doctype` — document type (e.g. `"article"`)

  ## Example

      {:ok, result} = ADSABSClient.Oracle.match_document(
        title: "Observation of Gravitational Waves from a Binary Black Hole Merger",
        abstract: "On September 14, 2015...",
        author: ["Abbott, B.P.", "Abbott, R."]
      )
      hd(result["match"])["bibcode"]  # => "2016PhRvL.116f1102A"
  """
  @spec match_document(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def match_document(opts \\ []) do
    if Keyword.get(opts, :title) == nil and Keyword.get(opts, :abstract) == nil do
      {:error, Error.validation_error("match_document requires at least :title or :abstract")}
    else
      body =
        %{}
        |> maybe_put("title", opts[:title])
        |> maybe_put("abstract", opts[:abstract])
        |> maybe_put("author", opts[:author])
        |> maybe_put("year", opts[:year])
        |> maybe_put("doctype", opts[:doctype])

      with {:ok, resp} <- HTTP.client().post("/oracle/matchdoc", body, []) do
        {:ok, resp.body}
      end
    end
  end

  # --- Private ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
