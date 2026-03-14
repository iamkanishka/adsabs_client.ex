defmodule ADSABSClient.Journals do
  @moduledoc """
  ADS Journals API — `/journals/*`.

  Provides journal metadata, including full names, ISSN, volume listings,
  and ADS holdings information.

  ## Examples

      # Get journal summary by bibstem
      {:ok, summary} = ADSABSClient.Journals.summary("ApJ")

      # Look up by ISSN
      {:ok, journal} = ADSABSClient.Journals.by_issn("0004-637X")

      # List volumes for a journal
      {:ok, vol_info} = ADSABSClient.Journals.volume("ApJ", "900")

      # Get ADS holdings
      {:ok, holdings} = ADSABSClient.Journals.holdings("ApJ")
  """

  alias ADSABSClient.{Error, HTTP}

  @doc """
  Get a summary of a journal by its bibstem code.

  ## Example

      {:ok, summary} = ADSABSClient.Journals.summary("ApJ")
      summary["summary"]["master"]["journal_name"]  # => "The Astrophysical Journal"
  """
  @spec summary(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def summary(bibstem) when is_binary(bibstem) do
    with {:ok, resp} <- HTTP.client().get("/journals/summary/#{URI.encode(bibstem)}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Get full journal details by bibstem.

  ## Example

      {:ok, journal} = ADSABSClient.Journals.journal("A&A")
  """
  @spec journal(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def journal(bibstem) when is_binary(bibstem) do
    with {:ok, resp} <- HTTP.client().get("/journals/journal/#{URI.encode(bibstem)}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Get details for a specific volume of a journal.

  ## Example

      {:ok, vol} = ADSABSClient.Journals.volume("ApJ", "900")
  """
  @spec volume(String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def volume(bibstem, volume_num) when is_binary(bibstem) and is_binary(volume_num) do
    with {:ok, resp} <- HTTP.client().get("/journals/volume/#{URI.encode(bibstem)}/#{volume_num}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Look up a journal by its ISSN.

  ## Example

      {:ok, journal} = ADSABSClient.Journals.by_issn("0004-637X")
  """
  @spec by_issn(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def by_issn(issn) when is_binary(issn) do
    with {:ok, resp} <- HTTP.client().get("/journals/issn/#{issn}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Get ADS holdings information for a journal (year/volume/page coverage).

  ## Example

      {:ok, holdings} = ADSABSClient.Journals.holdings("Icar")
  """
  @spec holdings(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def holdings(bibstem) when is_binary(bibstem) do
    with {:ok, resp} <- HTTP.client().get("/journals/holdings/#{URI.encode(bibstem)}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  List all known journals (paginated).

  ## Options

  - `:rows` — results per page (default: 100)
  - `:start` — offset

  ## Example

      {:ok, journals} = ADSABSClient.Journals.list(rows: 50)
  """
  @spec list(keyword()) :: {:ok, map()} | {:error, Error.t()}
  def list(opts \\ []) do
    params = %{
      "rows" => Keyword.get(opts, :rows, 100),
      "start" => Keyword.get(opts, :start, 0)
    }

    with {:ok, resp} <- HTTP.client().get("/journals/", params: params) do
      {:ok, resp.body}
    end
  end
end
