defmodule ADSABSClient.QueryPropertyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ADSABSClient.Query

  describe "Query.to_params/1 — property tests" do
    property "always produces a map with required keys" do
      check all(
              q_string <- string(:alphanumeric, min_length: 1),
              rows <- integer(1..2000),
              offset <- integer(0..10_000)
            ) do
        params =
          Query.new()
          |> Query.fulltext(q_string)
          |> Query.rows(rows)
          |> Query.start(offset)
          |> Query.to_params()

        assert Map.has_key?(params, "q")
        assert Map.has_key?(params, "fl")
        assert Map.has_key?(params, "rows")
        assert Map.has_key?(params, "start")
        assert is_binary(params["q"])
        assert is_binary(params["fl"])
        assert params["rows"] == rows
        assert params["start"] == offset
      end
    end

    property "build_query_string always returns a non-empty string" do
      check all(terms <- list_of(string(:alphanumeric, min_length: 1), min_length: 0)) do
        q = Enum.reduce(terms, Query.new(), &Query.fulltext(&2, &1))
        result = Query.build_query_string(q)

        assert is_binary(result)
        assert String.length(result) > 0
      end
    end

    property "year_range always produces valid Solr range syntax" do
      check all(
              from <- integer(1900..2030),
              to <- integer(from..2030)
            ) do
        q = Query.new() |> Query.year_range(from, to)
        str = Query.build_query_string(q)

        assert str =~ "year:["
        assert str =~ " TO "
        assert str =~ "#{from}"
        assert str =~ "#{to}"
      end
    end

    property "fields list is always joined with commas in params" do
      check all(
              fields <-
                list_of(
                  member_of(["bibcode", "title", "author", "year", "abstract", "citation_count"]),
                  min_length: 1
                )
            ) do
        params = Query.new() |> Query.fields(fields) |> Query.to_params()
        fl = params["fl"]

        assert is_binary(fl)
        assert fl == Enum.join(fields, ",")
      end
    end

    property "sort direction is always 'asc' or 'desc'" do
      check all(
              field <- member_of(["citation_count", "score", "year", "read_count"]),
              direction <- member_of([:asc, :desc])
            ) do
        params = Query.new() |> Query.sort(field, direction) |> Query.to_params()
        sort = params["sort"]

        assert sort == "#{field} #{direction}"
        assert sort =~ ~r/\basc\b|\bdesc\b/
      end
    end

    property "multiple clauses are always AND-joined" do
      check all(authors <- list_of(string(:alphanumeric, min_length: 1), min_length: 2, max_length: 5)) do
        q = Enum.reduce(authors, Query.new(), &Query.author(&2, &1))
        str = Query.build_query_string(q)

        # n authors => (n-1) AND separators
        and_count = str |> String.split(" AND ") |> length() |> Kernel.-(1)
        assert and_count == length(authors) - 1
      end
    end

    property "cursor_mark is always included in params when set" do
      check all(cursor <- string(:ascii, min_length: 1)) do
        params = Query.new() |> Query.cursor(cursor) |> Query.to_params()
        assert params["cursorMark"] == cursor
      end
    end
  end

  describe "Query composability — property tests" do
    property "any combination of builder calls returns a Query struct" do
      check all(
              use_author <- boolean(),
              use_title <- boolean(),
              use_year <- boolean(),
              year <- integer(1900..2030)
            ) do
        q =
          Query.new()
          |> then(fn q -> if use_author, do: Query.author(q, "Smith, J"), else: q end)
          |> then(fn q -> if use_title, do: Query.title(q, "stars"), else: q end)
          |> then(fn q -> if use_year, do: Query.year(q, year), else: q end)

        assert %Query{} = q
        params = Query.to_params(q)
        assert is_map(params)
      end
    end
  end
end
