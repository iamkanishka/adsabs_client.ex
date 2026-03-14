defmodule ADSABSClient.QueryTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ADSABSClient.Query

  describe "new/0" do
    test "creates an empty query with defaults" do
      q = Query.new()

      assert q.clauses == []
      assert q.rows == 10
      assert q.start == 0
      assert q.highlight == false
      assert is_nil(q.sort)
    end
  end

  describe "build_query_string/1" do
    test "returns '*:*' for empty query" do
      assert Query.build_query_string(Query.new()) == "*:*"
    end

    test "returns single clause" do
      q = Query.new() |> Query.fulltext("black holes")
      assert Query.build_query_string(q) == "black holes"
    end

    test "ANDs multiple clauses" do
      q =
        Query.new()
        |> Query.author("Einstein, A")
        |> Query.year(1905)

      result = Query.build_query_string(q)
      assert result == ~s(author:"Einstein, A" AND year:1905)
    end

    test "title wraps multi-word text in quotes" do
      q = Query.new() |> Query.title("general relativity")
      assert Query.build_query_string(q) == ~s(title:"general relativity")
    end

    test "title does not quote single words" do
      q = Query.new() |> Query.title("relativity")
      assert Query.build_query_string(q) == "title:relativity"
    end

    test "year_range produces Solr range syntax" do
      q = Query.new() |> Query.year_range(2010, 2020)
      assert Query.build_query_string(q) == "year:[2010 TO 2020]"
    end

    test "property adds property filter" do
      q = Query.new() |> Query.property(:refereed)
      assert Query.build_query_string(q) == "property:refereed"
    end

    test "min_citations adds range filter" do
      q = Query.new() |> Query.min_citations(100)
      assert Query.build_query_string(q) == "citation_count:[100 TO *]"
    end

    test "first_author uses ^ prefix" do
      q = Query.new() |> Query.first_author("Hawking, S")
      assert Query.build_query_string(q) == ~s(author:"^Hawking, S")
    end

    test "raw adds clause verbatim" do
      q = Query.new() |> Query.raw("property:openaccess AND year:2023")
      assert Query.build_query_string(q) == "property:openaccess AND year:2023"
    end
  end

  describe "to_params/1" do
    test "includes required q, fl, rows, start" do
      params = Query.new() |> Query.to_params()

      assert Map.has_key?(params, "q")
      assert Map.has_key?(params, "fl")
      assert Map.has_key?(params, "rows")
      assert Map.has_key?(params, "start")
    end

    test "fl is comma-separated field list" do
      params =
        Query.new()
        |> Query.fields(["title", "bibcode", "year"])
        |> Query.to_params()

      assert params["fl"] == "title,bibcode,year"
    end

    test "includes sort when set" do
      params =
        Query.new()
        |> Query.sort("citation_count", :desc)
        |> Query.to_params()

      assert params["sort"] == "citation_count desc"
    end

    test "does not include sort when not set" do
      params = Query.new() |> Query.to_params()
      refute Map.has_key?(params, "sort")
    end

    test "includes hl params when highlight enabled" do
      params =
        Query.new()
        |> Query.highlight(["abstract"])
        |> Query.to_params()

      assert params["hl"] == "true"
      assert params["hl.fl"] == "abstract"
    end

    test "does not include hl when highlight disabled" do
      params = Query.new() |> Query.to_params()
      refute Map.has_key?(params, "hl")
    end

    test "includes cursorMark when cursor is set" do
      params =
        Query.new()
        |> Query.cursor("AoE=")
        |> Query.to_params()

      assert params["cursorMark"] == "AoE="
    end

    test "includes facet params when facets are set" do
      params =
        Query.new()
        |> Query.facet("author")
        |> Query.facet("year")
        |> Query.to_params()

      assert params["facet"] == "true"
      assert "author" in params["facet.field"]
      assert "year" in params["facet.field"]
    end

    test "respects rows setting" do
      params = Query.new() |> Query.rows(50) |> Query.to_params()
      assert params["rows"] == 50
    end

    test "respects start offset" do
      params = Query.new() |> Query.start(100) |> Query.to_params()
      assert params["start"] == 100
    end
  end

  describe "rows/2 validation" do
    test "accepts valid row counts" do
      q = Query.new() |> Query.rows(2000)
      assert q.rows == 2000
    end
  end

  describe "composability" do
    test "all builder calls return Query structs" do
      q =
        Query.new()
        |> Query.fulltext("stars")
        |> Query.author("Smith, J")
        |> Query.title("stellar evolution")
        |> Query.abstract("nuclear")
        |> Query.year(2020)
        |> Query.year_range(2019, 2023)
        |> Query.property(:refereed)
        |> Query.min_citations(10)
        |> Query.journal("ApJ")
        |> Query.keyword("stellar")
        |> Query.fields(["title"])
        |> Query.sort("score", :desc)
        |> Query.rows(25)
        |> Query.start(0)
        |> Query.highlight()
        |> Query.facet("author")
        |> Query.cursor("*")

      assert %Query{} = q
      assert length(q.clauses) == 10
    end
  end
end
