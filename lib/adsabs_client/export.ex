defmodule ADSABSClient.Export do
  @moduledoc """
  ADS Export API — `/export/:format`.

  Exports bibliographic records in various citation formats.

  ## Supported Formats

  | Format | Function | Description |
  |---|---|---|
  | BibTeX | `bibtex/2` | Standard BibTeX entries |
  | EndNote | `endnote/2` | EndNote XML/text |
  | RIS | `ris/2` | Research Information Systems |
  | AASTeX | `aastex/2` | AAS Journal LaTeX macros |
  | MNRAS | `mnras/2` | Monthly Notices of the RAS |
  | Icarus | `icarus/2` | Icarus journal format |
  | Solar Physics | `soph/2` | Solar Physics journal |
  | RefAbsXML | `refabsxml/2` | ADS reference XML |
  | RSS | `rss/2` | RSS 2.0 feed |
  | Custom | `custom/3` | User-defined template |

  ## Examples

      bibcodes = ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

      {:ok, bibtex_str} = ADSABSClient.Export.bibtex(bibcodes)
      # => "@article{2016PhRvL.116f1102A,\\n  author = {Abbott, B. P.},\\n ...}"

      {:ok, ris_str} = ADSABSClient.Export.ris(bibcodes)

      # Custom format template
      {:ok, custom} = ADSABSClient.Export.custom(bibcodes, "%ZLabel %T\\n%A\\n%Y\\n")
  """

  alias ADSABSClient.{Error, HTTP}

  @export_formats ~w(bibtex endnote ris aastex mnras icarus soph refabsxml rss)a

  @type bibcodes :: [String.t()]
  @type export_result :: {:ok, String.t()} | {:error, Error.t()}

  for format <- @export_formats do
    format_str = to_string(format)

    @doc """
    Export bibcodes in #{format_str} format.

    ## Example

        {:ok, result} = ADSABSClient.Export.#{format_str}(["2016PhRvL.116f1102A"])
    """
    @spec unquote(format)(bibcodes(), keyword()) :: export_result()
    def unquote(format)(bibcodes, opts \\ []) do
      export(unquote(format_str), bibcodes, opts)
    end
  end

  @doc """
  Export bibcodes using a custom format template.

  Template tokens include `%T` (title), `%A` (authors), `%Y` (year), `%B` (abstract),
  `%C` (citation count), etc. See ADS documentation for the full list.

  ## Example

      {:ok, result} = ADSABSClient.Export.custom(
        ["2016PhRvL.116f1102A"],
        "%ZLabel %T\\n%A\\n%Y - %J\\n"
      )
  """
  @spec custom(bibcodes(), String.t(), keyword()) :: export_result()
  def custom(bibcodes, format_template, opts \\ [])
      when is_list(bibcodes) and is_binary(format_template) do
    if Enum.empty?(bibcodes) do
      {:error, Error.validation_error("export requires at least one bibcode")}
    else
      body = %{
        "bibcode" => bibcodes,
        "format" => format_template
      }

      body = maybe_put_journal_format(body, opts)

      with {:ok, resp} <- HTTP.client().post("/export/custom", body, []) do
        extract_export(resp.body)
      end
    end
  end

  # --- Private ---

  defp export(format, bibcodes, opts) when is_list(bibcodes) do
    if Enum.empty?(bibcodes) do
      {:error, Error.validation_error("export requires at least one bibcode")}
    else
      body = %{"bibcode" => bibcodes}
      body = maybe_put_journal_format(body, opts)

      with {:ok, resp} <- HTTP.client().post("/export/#{format}", body, []) do
        extract_export(resp.body)
      end
    end
  end

  defp extract_export(%{"export" => text}) when is_binary(text), do: {:ok, text}
  defp extract_export(%{"msg" => msg}) when is_binary(msg), do: {:ok, msg}

  defp extract_export(body) do
    {:error, Error.decode_error(inspect(body))}
  end

  defp maybe_put_journal_format(body, opts) do
    case Keyword.get(opts, :journal_format) do
      nil -> body
      fmt -> Map.put(body, "journalformat", fmt)
    end
  end
end
