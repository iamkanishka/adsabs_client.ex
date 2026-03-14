defmodule ADSABSClientTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.Test.Fixtures

  describe "top-level facade delegates" do
    test "search/2 delegates to Search.query/2" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, resp} = ADSABSClient.search("black holes")
      assert resp.num_found == 3
    end

    test "stream/2 delegates to Search.stream/2" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body(%{"nextCursorMark" => "*"}))
      end)

      result = "pulsars" |> ADSABSClient.stream() |> Enum.to_list()
      assert is_list(result)
    end

    test "export_bibtex/2 delegates to Export.bibtex/2" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/export/bibtex", _body, _opts ->
        Fixtures.ok_response(Fixtures.export_response_body("bibtex"))
      end)

      {:ok, bibtex} = ADSABSClient.export_bibtex(["2016PhRvL.116f1102A"])
      assert is_binary(bibtex)
    end

    test "metrics/2 delegates to Metrics.fetch/2" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/metrics", _body, _opts ->
        Fixtures.ok_response(Fixtures.metrics_response_body())
      end)

      {:ok, m} = ADSABSClient.metrics(["2016PhRvL.116f1102A"])
      assert m.indicators["h"] == 3
    end

    test "count/1 delegates to Pagination.count/1" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        assert opts[:params]["rows"] == 0
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, n} = ADSABSClient.count("stars")
      assert n == 3
    end

    test "collect_all/2 delegates to Pagination.collect_all/2" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body(%{"nextCursorMark" => "*"}))
      end)

      docs = ADSABSClient.collect_all("pulsars")
      assert is_list(docs)
    end

    test "status/0 delegates to Accounts.status/0" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, status} = ADSABSClient.status()
      assert status.authenticated == true
    end

    test "validate_token/0 delegates to Accounts.validate_token/0" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      assert :ok = ADSABSClient.validate_token()
    end
  end
end
