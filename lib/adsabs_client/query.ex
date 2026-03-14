defmodule ADSABSClient.Query do
  @moduledoc """
  Composable Solr query builder for the ADS Search API.

  Instead of constructing raw Solr query strings, use this module to build
  queries programmatically. All clauses are AND-combined by default.

  ## Example

      alias ADSABSClient.Query

      # Simple search
      Query.new()
      |> Query.fulltext("gravitational waves")
      |> Query.year_range(2015, 2023)
      |> Query.property(:refereed)
      |> Query.fields(["title", "author", "bibcode", "citation_count"])
      |> Query.sort("citation_count", :desc)
      |> Query.rows(25)
      |> ADSABSClient.Search.query()

      # Author + title search
      Query.new()
      |> Query.author("Einstein, A")
      |> Query.title("general relativity")
      |> Query.build_query_string()
      # => "author:\\"Einstein, A\\" title:general relativity"

  ## Field Reference

  Common ADS Solr fields: `bibcode`, `title`, `author`, `abstract`,
  `year`, `citation_count`, `read_count`, `identifier`, `doi`,
  `property`, `pub`, `volume`, `issue`, `page`, `keyword`.
  """

  @type sort_direction :: :asc | :desc

  @type t :: %__MODULE__{
          clauses: [String.t()],
          fields: [String.t()],
          sort: String.t() | nil,
          rows: pos_integer(),
          start: non_neg_integer(),
          highlight: boolean(),
          highlight_fields: [String.t()],
          facets: [String.t()],
          cursor_mark: String.t() | nil,
          fl_operator: :and | :or
        }

  defstruct clauses: [],
            fields: ["bibcode", "title", "author", "year", "abstract"],
            sort: nil,
            rows: 10,
            start: 0,
            highlight: false,
            highlight_fields: [],
            facets: [],
            cursor_mark: nil,
            fl_operator: :and

  @doc "Create a new empty query."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Add a full-text search clause (searches across title, abstract, body)."
  @spec fulltext(t(), String.t()) :: t()
  def fulltext(%__MODULE__{} = q, text) when is_binary(text) do
    add_clause(q, escape(text))
  end

  @doc "Search in the `title` field."
  @spec title(t(), String.t()) :: t()
  def title(%__MODULE__{} = q, text) when is_binary(text) do
    add_clause(q, ~s(title:#{quote_if_spaces(text)}))
  end

  @doc "Search in the `abstract` field."
  @spec abstract(t(), String.t()) :: t()
  def abstract(%__MODULE__{} = q, text) when is_binary(text) do
    add_clause(q, ~s(abstract:#{quote_if_spaces(text)}))
  end

  @doc """
  Search by author name.

  ADS supports several author formats:
  - `"Einstein, A"` — last name, first initial
  - `"^Einstein"` — first author only
  - `"Einstein, Albert"` — full name
  """
  @spec author(t(), String.t()) :: t()
  def author(%__MODULE__{} = q, name) when is_binary(name) do
    add_clause(q, ~s(author:"#{name}"))
  end

  @doc "Restrict to first author only."
  @spec first_author(t(), String.t()) :: t()
  def first_author(%__MODULE__{} = q, name) when is_binary(name) do
    add_clause(q, ~s(author:"^#{name}"))
  end

  @doc "Filter by a specific publication year."
  @spec year(t(), pos_integer()) :: t()
  def year(%__MODULE__{} = q, year) when is_integer(year) do
    add_clause(q, "year:#{year}")
  end

  @doc "Filter by a range of publication years (inclusive)."
  @spec year_range(t(), pos_integer(), pos_integer()) :: t()
  def year_range(%__MODULE__{} = q, from, to) when is_integer(from) and is_integer(to) do
    add_clause(q, "year:[#{from} TO #{to}]")
  end

  @doc """
  Filter by a paper property.

  Common properties: `:refereed`, `:not_refereed`, `:openaccess`, `:eprint`,
  `:astronomy`, `:physics`, `:earthscience`.
  """
  @spec property(t(), atom() | String.t()) :: t()
  def property(%__MODULE__{} = q, prop) when is_atom(prop) do
    add_clause(q, "property:#{prop}")
  end

  def property(%__MODULE__{} = q, prop) when is_binary(prop) do
    add_clause(q, "property:#{prop}")
  end

  @doc "Filter by minimum citation count."
  @spec min_citations(t(), non_neg_integer()) :: t()
  def min_citations(%__MODULE__{} = q, n) when is_integer(n) and n >= 0 do
    add_clause(q, "citation_count:[#{n} TO *]")
  end

  @doc "Filter by bibcode."
  @spec bibcode(t(), String.t()) :: t()
  def bibcode(%__MODULE__{} = q, code) when is_binary(code) do
    add_clause(q, ~s(bibcode:#{code}))
  end

  @doc "Filter by DOI."
  @spec doi(t(), String.t()) :: t()
  def doi(%__MODULE__{} = q, doi_str) when is_binary(doi_str) do
    add_clause(q, ~s(doi:#{doi_str}))
  end

  @doc "Filter by journal/publication (bibstem)."
  @spec journal(t(), String.t()) :: t()
  def journal(%__MODULE__{} = q, bibstem) when is_binary(bibstem) do
    add_clause(q, ~s(bibstem:#{bibstem}))
  end

  @doc "Filter by keyword."
  @spec keyword(t(), String.t()) :: t()
  def keyword(%__MODULE__{} = q, kw) when is_binary(kw) do
    add_clause(q, ~s(keyword:#{quote_if_spaces(kw)}))
  end

  @doc "Add a raw Solr clause (escape manually)."
  @spec raw(t(), String.t()) :: t()
  def raw(%__MODULE__{} = q, clause) when is_binary(clause) do
    add_clause(q, clause)
  end

  @doc "Set the list of fields to return."
  @spec fields(t(), [String.t()]) :: t()
  def fields(%__MODULE__{} = q, fl) when is_list(fl) do
    %{q | fields: fl}
  end

  @doc "Set sort order. Field is a Solr field name, direction is `:asc` or `:desc`."
  @spec sort(t(), String.t(), sort_direction()) :: t()
  def sort(%__MODULE__{} = q, field, direction \\ :desc)
      when is_binary(field) and direction in [:asc, :desc] do
    %{q | sort: "#{field} #{direction}"}
  end

  @doc "Set number of results per page (max 2000 per ADS limits)."
  @spec rows(t(), pos_integer()) :: t()
  def rows(%__MODULE__{} = q, n) when is_integer(n) and n > 0 and n <= 2000 do
    %{q | rows: n}
  end

  @doc "Set the offset for pagination."
  @spec start(t(), non_neg_integer()) :: t()
  def start(%__MODULE__{} = q, offset) when is_integer(offset) and offset >= 0 do
    %{q | start: offset}
  end

  @doc "Enable full-text highlighting on specified fields."
  @spec highlight(t(), [String.t()]) :: t()
  def highlight(%__MODULE__{} = q, hl_fields \\ ["abstract", "body"]) do
    %{q | highlight: true, highlight_fields: hl_fields}
  end

  @doc "Add a facet field."
  @spec facet(t(), String.t()) :: t()
  def facet(%__MODULE__{} = q, field) when is_binary(field) do
    %{q | facets: [field | q.facets]}
  end

  @doc "Set cursor mark for deep pagination (use `\"*\"` to start)."
  @spec cursor(t(), String.t()) :: t()
  def cursor(%__MODULE__{} = q, mark \\ "*") do
    %{q | cursor_mark: mark}
  end

  @doc """
  Build the complete query parameter map for the ADS Search API.

  ## Example

      Query.new()
      |> Query.author("Einstein")
      |> Query.year_range(1950, 1960)
      |> Query.to_params()
      # => %{"q" => "author:\\"Einstein\\" year:[1950 TO 1960]", "fl" => "bibcode,title,author,year,abstract", ...}
  """
  @spec to_params(t()) :: %{String.t() => String.t() | [String.t()] | non_neg_integer()}
  def to_params(%__MODULE__{} = q) do
    base = %{
      "q" => build_query_string(q),
      "fl" => Enum.join(q.fields, ","),
      "rows" => q.rows,
      "start" => q.start
    }

    base
    |> maybe_add_sort(q)
    |> maybe_add_highlight(q)
    |> maybe_add_facets(q)
    |> maybe_add_cursor(q)
  end

  @doc "Build just the Solr query string from accumulated clauses."
  @spec build_query_string(t()) :: String.t()
  def build_query_string(%__MODULE__{clauses: []}), do: "*:*"
  def build_query_string(%__MODULE__{clauses: clauses}), do: clauses |> Enum.reverse() |> Enum.join(" AND ")

  # --- Private helpers ---

  defp add_clause(%__MODULE__{clauses: clauses} = q, clause) do
    %{q | clauses: [clause | clauses]}
  end

  defp escape(text) do
    # Escape Solr special characters when not in a phrase
    String.replace(text, ~r/([+\-&&||!(){}[\]^~*?:\\\/])/, "\\\\\\1")
  end

  defp quote_if_spaces(text) do
    if String.contains?(text, " "), do: ~s("#{text}"), else: text
  end

  defp maybe_add_sort(params, %{sort: nil}), do: params
  defp maybe_add_sort(params, %{sort: sort}), do: Map.put(params, "sort", sort)

  defp maybe_add_highlight(params, %{highlight: false}), do: params

  defp maybe_add_highlight(params, %{highlight: true, highlight_fields: fields}) do
    params
    |> Map.put("hl", "true")
    |> Map.put("hl.fl", Enum.join(fields, ","))
  end

  defp maybe_add_facets(params, %{facets: []}), do: params

  defp maybe_add_facets(params, %{facets: facets}) do
    params
    |> Map.put("facet", "true")
    |> Map.put("facet.field", facets)
  end

  defp maybe_add_cursor(params, %{cursor_mark: nil}), do: params

  defp maybe_add_cursor(params, %{cursor_mark: mark}) do
    Map.put(params, "cursorMark", mark)
  end
end
