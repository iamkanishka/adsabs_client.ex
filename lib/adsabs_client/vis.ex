defmodule ADSABSClient.Vis do
  @moduledoc """
  ADS Visualization API — `/vis/*`.

  Returns data for building network and word-cloud visualizations.

  ## Examples

      bibcodes = ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

      {:ok, network}   = ADSABSClient.Vis.author_network(bibcodes)
      {:ok, paper_net} = ADSABSClient.Vis.paper_network(bibcodes)
      {:ok, cloud}     = ADSABSClient.Vis.word_cloud(bibcodes)
  """

  alias ADSABSClient.{Error, HTTP}

  @doc """
  Generate author collaboration network data for a set of bibcodes.

  The returned data can be rendered as a force-directed graph.

  ## Options

  - `:max_authors` — limit the number of author nodes in the network

  ## Example

      {:ok, data} = ADSABSClient.Vis.author_network(bibcodes)
      data["data"]["nodes"]   # author nodes
      data["data"]["links"]   # collaboration edges
  """
  @spec author_network([String.t()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def author_network(bibcodes, opts \\ []) when is_list(bibcodes) do
    case validate_bibcodes(bibcodes) do
      {:error, reason} ->
        {:error, Error.validation_error("author_network requires at least one bibcode (#{reason})")}

      :ok ->
        with {:ok, resp} <- HTTP.client().post("/vis/author-network", build_vis_body(bibcodes, opts), []) do
          {:ok, resp.body}
        end
    end
  end

  @doc """
  Generate paper co-citation network data.

  Papers that are frequently cited together appear as clusters.

  ## Example

      {:ok, data} = ADSABSClient.Vis.paper_network(bibcodes)
      data["data"]["nodes"]   # paper nodes
      data["data"]["links"]   # citation links
  """
  @spec paper_network([String.t()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def paper_network(bibcodes, opts \\ []) when is_list(bibcodes) do
    case validate_bibcodes(bibcodes) do
      {:error, reason} ->
        {:error, Error.validation_error("paper_network requires at least one bibcode (#{reason})")}

      :ok ->
        with {:ok, resp} <- HTTP.client().post("/vis/paper-network", build_vis_body(bibcodes, opts), []) do
          {:ok, resp.body}
        end
    end
  end

  @doc """
  Generate word cloud data from abstracts of the given bibcodes.

  ## Options

  - `:num_words` — maximum number of words to include (default: ADS server default)

  ## Example

      {:ok, data} = ADSABSClient.Vis.word_cloud(bibcodes)
      data["words"]  # => [%{"text" => "black hole", "size" => 42}, ...]
  """
  @spec word_cloud([String.t()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def word_cloud(bibcodes, opts \\ []) when is_list(bibcodes) do
    case validate_bibcodes(bibcodes) do
      {:error, reason} ->
        {:error, Error.validation_error("word_cloud requires at least one bibcode (#{reason})")}

      :ok ->
        with {:ok, resp} <- HTTP.client().post("/vis/word-cloud", build_vis_body(bibcodes, opts), []) do
          {:ok, resp.body}
        end
    end
  end

  # --- Private ---

  defp validate_bibcodes([_ | _]), do: :ok
  defp validate_bibcodes([]), do: {:error, "empty list"}

  defp build_vis_body(bibcodes, opts) do
    %{"bibcodes" => bibcodes}
    |> maybe_put("maxauthor", opts[:max_authors])
    |> maybe_put("numwords", opts[:num_words])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
