defmodule AdsClient.Export do
  @moduledoc """
  Export API for bibliographic formats.
  """

  alias AdsClient.{HTTP, Error}

  @formats %{
    bibtex: "bibtex",
    bibtexabs: "bibtexabs",
    ads: "ads",
    endnote: "endnote",
    procite: "procite",
    ris: "ris",
    refworks: "refworks",
    medlars: "medlars",
    dcxml: "dcxml",
    refxml: "refxml",
    refabsxml: "refabsxml",
    aastex: "aastex",
    icarus: "icarus",
    mnras: "mnras",
    soph: "soph",
    votable: "votable",
    rss: "rss"
  }

  @spec export(list(String.t()), atom(), keyword()) ::
    {:ok, String.t()} | {:error, Error.t()}
  def export(bibcodes, format, opts \\ []) when is_list(bibcodes) and is_atom(format) do
    format_str = Map.get(@formats, format)

    unless format_str do
       {:error, Error.new(:validation, "Invalid export format: #{format}")}
    end

    body = %{
      "bibcode" => bibcodes,
      "sort" => Keyword.get(opts, :sort, "date desc"),
      "format" => format_str
    }
    |> add_format_options(opts)

    case HTTP.post("/export/#{format_str}", body: body) do
      {:ok, %{body: response}} when is_map(response) ->
        {:ok, response["export"]}
      {:ok, %{body: response}} when is_binary(response) ->
        {:ok, response}
      {:error, _} = error ->
        error
    end
  end

  @spec export!(list(String.t()), atom(), keyword()) :: String.t()
  def export!(bibcodes, format, opts \\ []) do
    case export(bibcodes, format, opts) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  @spec list_formats() :: list(atom())
  def list_formats, do: Map.keys(@formats)

  defp add_format_options(body, opts) do
    body
    |> add_if_present("maxauthor", opts[:maxauthor])
    |> add_if_present("authorcutoff", opts[:authorcutoff])
    |> add_if_present("keyformat", opts[:keyformat])
    |> add_if_present("journalformat", opts[:journalformat])
  end

  defp add_if_present(map, _key, nil), do: map
  defp add_if_present(map, key, value), do: Map.put(map, key, value)
end
