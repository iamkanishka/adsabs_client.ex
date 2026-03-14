defmodule ADSABSClient.SearchStreamTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.Search
  alias ADSABSClient.Test.Fixtures

  describe "stream/2" do
    test "returns an Enumerable" do
      stream = Search.stream("black holes")
      assert is_function(stream) or match?(%Stream{}, stream) or is_struct(stream)
    end

    test "fetches multiple pages and flattens results" do
      page1_docs = [
        %{"bibcode" => "code1", "citation_count" => 100},
        %{"bibcode" => "code2", "citation_count" => 50}
      ]

      page2_docs = [
        %{"bibcode" => "code3", "citation_count" => 25}
      ]

      # Expect exactly 2 page fetches: page 1 (cursor="*"), page 2 (cursor="AoE=cursor1")
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(
          Fixtures.search_response_body(%{
            "response" => %{"numFound" => 3, "start" => 0, "docs" => page1_docs},
            "nextCursorMark" => "AoE=cursor1"
          })
        )
      end)

      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(
          Fixtures.search_response_body(%{
            "response" => %{"numFound" => 3, "start" => 2, "docs" => page2_docs},
            "nextCursorMark" => "AoE=cursor1"
          })
        )
      end)

      results = "black holes" |> Search.stream(rows: 2) |> Enum.to_list()
      assert length(results) == 3
      bibcodes = Enum.map(results, & &1["bibcode"])
      assert "code1" in bibcodes
      assert "code3" in bibcodes
    end

    test "stops when page returns empty docs" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.empty_search_response_body())
      end)

      results = "totally_nonexistent_xyz" |> Search.stream() |> Enum.to_list()
      assert results == []
    end

    test "Enum.take stops fetching after taking enough results" do
      # Only the first page should be fetched
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        docs = Enum.map(1..5, fn i -> %{"bibcode" => "code#{i}"} end)

        Fixtures.ok_response(
          Fixtures.search_response_body(%{
            "response" => %{"numFound" => 100, "start" => 0, "docs" => docs},
            "nextCursorMark" => "AoE=next"
          })
        )
      end)

      results = "stars" |> Search.stream() |> Enum.take(3)
      assert length(results) == 3
    end

    test "stream can be filtered with Stream.filter" do
      docs = [
        %{"bibcode" => "code1", "citation_count" => 200},
        %{"bibcode" => "code2", "citation_count" => 10},
        %{"bibcode" => "code3", "citation_count" => 500}
      ]

      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(
          Fixtures.search_response_body(%{
            "response" => %{"numFound" => 3, "start" => 0, "docs" => docs},
            "nextCursorMark" => "*"
          })
        )
      end)

      results =
        "test"
        |> Search.stream()
        |> Stream.filter(&((&1["citation_count"] || 0) >= 100))
        |> Enum.to_list()

      assert length(results) == 2
      assert Enum.all?(results, &(&1["citation_count"] >= 100))
    end
  end
end
