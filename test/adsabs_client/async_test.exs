defmodule ADSABSClient.AsyncTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Async, Error}
  alias ADSABSClient.Test.Fixtures

  describe "search_all/2" do
    test "runs multiple queries and returns results keyed by input" do
      queries = ["black holes", "neutron stars"]

      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      results = Async.search_all(queries)

      assert length(results) == 2

      Enum.each(results, fn {_query, result} ->
        assert match?({:ok, _}, result)
      end)
    end

    test "each result tuple contains the original query" do
      queries = ["pulsars", "quasars"]

      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      results = Async.search_all(queries)
      returned_queries = Enum.map(results, fn {q, _} -> q end)

      assert "pulsars" in returned_queries
      assert "quasars" in returned_queries
    end

    test "handles errors gracefully without crashing" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.error_response(401, "Unauthorized")
      end)

      results = Async.search_all(["stars"])

      assert [{_query, {:error, %Error{type: :unauthorized}}}] = results
    end

    test "returns empty list for empty input" do
      results = Async.search_all([])
      assert results == []
    end
  end

  describe "fetch_metrics/2" do
    test "fetches metrics for multiple groups" do
      groups = [
        ["2016PhRvL.116f1102A"],
        ["2019ApJ...882L..24A"]
      ]

      stub(ADSABSClient.HTTP.Mock, :post, fn "/metrics", _body, _opts ->
        Fixtures.ok_response(Fixtures.metrics_response_body())
      end)

      results = Async.fetch_metrics(groups)

      assert length(results) == 2

      Enum.each(results, fn {_group, result} ->
        assert match?({:ok, _}, result)
      end)
    end

    test "returns empty list for empty input" do
      results = Async.fetch_metrics([])
      assert results == []
    end
  end

  describe "export_all/3" do
    test "concatenates results from all groups" do
      groups = [["code1"], ["code2"]]

      stub(ADSABSClient.HTTP.Mock, :post, fn "/export/bibtex", _body, _opts ->
        Fixtures.ok_response(%{"export" => "@article{...}"})
      end)

      {:ok, combined} = Async.export_all(groups, :bibtex)

      assert is_binary(combined)
      assert combined =~ "@article"
    end

    test "returns error list when any group fails" do
      stub(ADSABSClient.HTTP.Mock, :post, fn "/export/bibtex", _body, _opts ->
        Fixtures.error_response(500)
      end)

      result = Async.export_all([["code1"], ["code2"]], :bibtex)

      assert match?({:error, [_ | _]}, result)
    end
  end

  describe "map/3" do
    test "maps a function over items concurrently" do
      items = [1, 2, 3]

      results = Async.map(items, fn n -> n * 2 end)

      assert length(results) == 3
      values = Enum.map(results, fn {_item, v} -> v end)
      assert 2 in values
      assert 4 in values
      assert 6 in values
    end

    test "returns empty list for empty input" do
      assert Async.map([], fn x -> x end) == []
    end
  end
end
