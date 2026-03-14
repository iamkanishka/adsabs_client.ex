defmodule ADSABSClient.SearchTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Query, Search}
  alias ADSABSClient.Search.Response
  alias ADSABSClient.Test.Fixtures

  describe "query/2 with string" do
    test "returns a Response struct on success" do
      body = Fixtures.search_response_body()

      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(body)
      end)

      {:ok, resp} = Search.query("black holes")

      assert %Response{} = resp
      assert resp.num_found == 3
      assert length(resp.docs) == 3
      assert resp.qtime == 12
    end

    test "parses rate limit info from headers" do
      body = Fixtures.search_response_body()

      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(body, Fixtures.rate_limit_headers())
      end)

      {:ok, resp} = Search.query("stars")

      assert resp.rate_limit.limit == 5000
      assert resp.rate_limit.remaining == 4980
    end

    test "returns first document with expected fields" do
      body = Fixtures.search_response_body()

      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(body)
      end)

      {:ok, resp} = Search.query("gravitational waves")
      doc = hd(resp.docs)

      assert doc["bibcode"] == "2016PhRvL.116f1102A"
      assert doc["citation_count"] == 8500
    end

    test "handles empty results gracefully" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.empty_search_response_body())
      end)

      {:ok, resp} = Search.query("xyzzy_nonexistent_term_12345")

      assert resp.num_found == 0
      assert resp.docs == []
    end

    test "returns validation error for 401" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.error_response(401, "Unauthorized")
      end)

      {:error, error} = Search.query("stars")

      assert %Error{type: :unauthorized} = error
    end

    test "returns rate_limited error for 429" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.rate_limited_response(90)
      end)

      {:error, error} = Search.query("stars")

      assert %Error{type: :rate_limited} = error
      assert error.retry_after == 90
    end
  end

  describe "query/2 with Query struct" do
    test "accepts a Query struct" do
      body = Fixtures.search_response_body()

      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        params = opts[:params]
        assert params["q"] =~ "author"
        Fixtures.ok_response(body)
      end)

      q =
        Query.new()
        |> Query.author("Hawking, S")
        |> Query.year_range(1970, 2018)
        |> Query.fields(["title", "bibcode"])

      {:ok, resp} = Search.query(q)
      assert resp.num_found == 3
    end

    test "passes rows and sort from Query struct" do
      body = Fixtures.search_response_body()

      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        params = opts[:params]
        assert params["rows"] == 25
        assert params["sort"] == "citation_count desc"
        Fixtures.ok_response(body)
      end)

      q =
        Query.new()
        |> Query.fulltext("pulsars")
        |> Query.rows(25)
        |> Query.sort("citation_count", :desc)

      {:ok, _} = Search.query(q)
    end
  end

  describe "citations/2" do
    test "wraps bibcodes in citations() operator" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        assert opts[:params]["q"] =~ "citations("
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, _} = Search.citations(["2016PhRvL.116f1102A"])
    end
  end

  describe "references/2" do
    test "wraps bibcodes in references() operator" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        assert opts[:params]["q"] =~ "references("
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, _} = Search.references(["2016PhRvL.116f1102A"])
    end
  end

  describe "trending/2" do
    test "wraps query in trending() operator" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        assert opts[:params]["q"] =~ "trending("
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, _} = Search.trending("black holes")
    end
  end

  describe "bigquery/2" do
    test "returns validation error for empty bibcodes" do
      {:error, error} = Search.bigquery([])
      assert error.type == :validation_error
    end

    test "posts to /search/bigquery with plain-text bibcode body" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/search/bigquery", body, opts ->
        assert is_binary(body)
        assert String.starts_with?(body, "bibcode\n")
        assert String.contains?(body, "2016PhRvL.116f1102A")
        assert opts[:content_type] == "big-query/csv"
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, resp} = Search.bigquery(["2016PhRvL.116f1102A"])
      assert resp.num_found == 3
    end

    test "includes all bibcodes in body" do
      bibcodes = ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

      expect(ADSABSClient.HTTP.Mock, :post, fn "/search/bigquery", body, _opts ->
        for code <- bibcodes, do: assert(String.contains?(body, code))
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, _} = Search.bigquery(bibcodes)
    end
  end

  describe "Search.Response.from_response/2" do
    test "parses facets correctly" do
      body =
        Fixtures.search_response_body(%{
          "facet_counts" => %{
            "facet_fields" => %{
              "author_facet" => ["Smith, J", 5, "Jones, A", 3]
            }
          }
        })

      resp = Response.from_response(body)

      assert Map.has_key?(resp.facets, "author_facet")
      assert {"Smith, J", 5} in resp.facets["author_facet"]
    end

    test "parses next_cursor_mark" do
      body = Fixtures.search_response_body(%{"nextCursorMark" => "AoE=xyz"})
      resp = Response.from_response(body)

      assert resp.next_cursor_mark == "AoE=xyz"
    end
  end
end
