defmodule AdsabsClient.AuthorAffiliation do
  @moduledoc """
  Author Affiliation API for generating collaboration reports.
  """

  alias AdsabsClient.{HTTP, Error}

  @spec search(list(String.t()), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def search(bibcodes, opts \\ []) do
    body = %{
      "bibcodes" => bibcodes,
      "maxauthor" => Keyword.get(opts, :maxauthor, 200),
      "numyears" => Keyword.get(opts, :numyears, 5)
    }

    case HTTP.post("/author-affiliation/search", body: body) do
      {:ok, %{body: response}} -> {:ok, response}
      {:error, _} = error -> error
    end
  end
end
