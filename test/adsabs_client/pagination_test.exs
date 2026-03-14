defmodule ADSABSClient.PaginationTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Pagination}
  alias ADSABSClient.Test.Fixtures

  describe "count/1" do
    test "returns total num_found from a rows=0 query" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        assert opts[:params]["rows"] == 0
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, count} = Pagination.count("black holes")
      assert count == 3
    end

    test "returns 0 for empty result sets" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.empty_search_response_body())
      end)

      {:ok, count} = Pagination.count("xyzzy_nonexistent")
      assert count == 0
    end

    test "forwards errors" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.error_response(401)
      end)

      assert {:error, %Error{type: :unauthorized}} = Pagination.count("stars")
    end
  end

  describe "needs_cursor?/1" do
    test "returns false for small result sets" do
      refute Pagination.needs_cursor?(100)
      refute Pagination.needs_cursor?(9_999)
      refute Pagination.needs_cursor?(10_000)
    end

    test "returns true for large result sets" do
      assert Pagination.needs_cursor?(10_001)
      assert Pagination.needs_cursor?(100_000)
      assert Pagination.needs_cursor?(1_000_000)
    end
  end

  describe "pages/2" do
    test "streams page structs" do
      docs = [%{"bibcode" => "code1"}, %{"bibcode" => "code2"}]

      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(
          Fixtures.search_response_body(%{
            "response" => %{"numFound" => 2, "start" => 0, "docs" => docs},
            "nextCursorMark" => "*"
          })
        )
      end)

      pages = "stars" |> Pagination.pages() |> Enum.to_list()

      assert length(pages) == 1
      assert length(hd(pages).docs) == 2
    end

    test "stops at max_results" do
      big_docs = Enum.map(1..200, fn i -> %{"bibcode" => "code#{i}"} end)

      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(
          Fixtures.search_response_body(%{
            "response" => %{"numFound" => 10_000, "start" => 0, "docs" => big_docs},
            "nextCursorMark" => "next_page_cursor"
          })
        )
      end)

      pages = "stars" |> Pagination.pages(rows: 200, max_results: 200) |> Enum.to_list()
      total_docs = Enum.sum(Enum.map(pages, fn p -> length(p.docs) end))

      assert total_docs <= 200
    end
  end

  describe "collect_all/2" do
    test "returns flat list of all docs" do
      docs = Fixtures.search_response_body()["response"]["docs"]

      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(
          Fixtures.search_response_body(%{
            "nextCursorMark" => "*"
          })
        )
      end)

      result = Pagination.collect_all("black holes")
      assert is_list(result)
      assert length(result) == length(docs)
    end
  end
end
