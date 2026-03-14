defmodule ADSABSClient.Resolver do
  @moduledoc """
  ADS Resolver API — `/resolver/:bibcode`.

  Resolves a bibcode to full-text, data, and related resource links.

  ## Link Types

  | Type | Description |
  |---|---|
  | `"abstract"` | ADS abstract page |
  | `"citations"` | Papers citing this record |
  | `"references"` | References in this paper |
  | `"full"` | Publisher full-text link |
  | `"preprint"` | arXiv/preprint link |
  | `"data"` | Associated data links (MAST, NED, etc.) |
  | `"graphics"` | Figures and graphics |
  | `"esource"` | Electronic source links |
  | `"associated"` | Associated works |
  | `"metrics"` | Metrics page |
  | `"similar"` | Similar papers |

  ## Examples

      {:ok, links} = ADSABSClient.Resolver.resolve("2016PhRvL.116f1102A")

      {:ok, link} = ADSABSClient.Resolver.resolve("2016PhRvL.116f1102A", :full)
      link["resolved"]["url"]  # => "https://journals.aps.org/..."

      {:ok, preprint} = ADSABSClient.Resolver.resolve("2016PhRvL.116f1102A", :preprint)
  """

  alias ADSABSClient.{Error, HTTP}

  @valid_link_types ~w(abstract citations references full preprint data graphics esource associated metrics similar)

  @doc """
  Resolve all links for a bibcode.

  Returns all available resource links for the paper.

  ## Example

      {:ok, result} = ADSABSClient.Resolver.resolve("2016PhRvL.116f1102A")
      result["links"]["count"]
  """
  @spec resolve(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(bibcode) when is_binary(bibcode) do
    with {:ok, resp} <- HTTP.client().get("/resolver/#{URI.encode(bibcode)}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Resolve a specific link type for a bibcode.

  ## Example

      {:ok, result} = ADSABSClient.Resolver.resolve("2016PhRvL.116f1102A", :preprint)
      result["resolved"]["url"]  # arXiv URL
  """
  @spec resolve(String.t(), atom() | String.t()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(bibcode, link_type) when is_binary(bibcode) do
    type_str = to_string(link_type)

    if type_str in @valid_link_types do
      with {:ok, resp} <- HTTP.client().get("/resolver/#{URI.encode(bibcode)}/#{type_str}", []) do
        {:ok, resp.body}
      end
    else
      {:error,
       Error.validation_error("Invalid link type: #{type_str}. Valid types: #{Enum.join(@valid_link_types, ", ")}")}
    end
  end

  @doc """
  Convenience wrapper: get the full-text URL for a bibcode.

  Returns `{:ok, url_string}` or `{:error, error}`.
  """
  @spec full_text_url(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def full_text_url(bibcode) when is_binary(bibcode) do
    with {:ok, result} <- resolve(bibcode, :full) do
      case get_in(result, ["resolved", "url"]) do
        nil -> {:error, Error.not_found("No full-text URL for #{bibcode}")}
        url -> {:ok, url}
      end
    end
  end

  @doc """
  Get the arXiv/preprint URL for a bibcode.
  """
  @spec preprint_url(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def preprint_url(bibcode) when is_binary(bibcode) do
    with {:ok, result} <- resolve(bibcode, :preprint) do
      case get_in(result, ["resolved", "url"]) do
        nil -> {:error, Error.not_found("No preprint URL for #{bibcode}")}
        url -> {:ok, url}
      end
    end
  end
end
