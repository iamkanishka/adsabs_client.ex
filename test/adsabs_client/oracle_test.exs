defmodule ADSABSClient.OracleTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Oracle}
  alias ADSABSClient.Test.Fixtures

  describe "also_read/2" do
    test "fetches also-read recommendations" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/oracle/alsoread", opts ->
        assert opts[:params]["bibcodes"] =~ "2016PhRvL.116f1102A"
        Fixtures.ok_response(%{"bibcodes" => ["2019ApJ...882L..24A"]})
      end)

      {:ok, result} = Oracle.also_read(["2016PhRvL.116f1102A"])
      assert is_list(result["bibcodes"])
    end

    test "returns validation error for empty bibcodes" do
      {:error, error} = Oracle.also_read([])
      assert error.type == :validation_error
    end

    test "joins multiple bibcodes with comma" do
      bibcodes = ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

      expect(ADSABSClient.HTTP.Mock, :get, fn "/oracle/alsoread", opts ->
        assert opts[:params]["bibcodes"] == Enum.join(bibcodes, ",")
        Fixtures.ok_response(%{"bibcodes" => []})
      end)

      {:ok, _} = Oracle.also_read(bibcodes)
    end
  end

  describe "match_document/1" do
    test "matches by title and abstract" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/oracle/matchdoc", body, _opts ->
        assert body["title"] == "Gravitational wave detection"
        assert body["abstract"] =~ "LIGO"
        Fixtures.ok_response(%{"match" => [%{"bibcode" => "2016PhRvL.116f1102A", "score" => 0.99}]})
      end)

      {:ok, result} =
        Oracle.match_document(
          title: "Gravitational wave detection",
          abstract: "LIGO detected a signal"
        )

      assert hd(result["match"])["bibcode"] == "2016PhRvL.116f1102A"
    end

    test "returns validation error when neither title nor abstract provided" do
      {:error, error} = Oracle.match_document(author: ["Smith, J"])
      assert error.type == :validation_error
      assert error.message =~ "title"
    end

    test "accepts title-only query" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/oracle/matchdoc", body, _opts ->
        assert Map.has_key?(body, "title")
        refute Map.has_key?(body, "abstract")
        Fixtures.ok_response(%{"match" => []})
      end)

      {:ok, _} = Oracle.match_document(title: "Gravitational Waves")
    end

    test "includes author list when provided" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/oracle/matchdoc", body, _opts ->
        assert body["author"] == ["Abbott, B.P.", "Abbott, R."]
        Fixtures.ok_response(%{"match" => []})
      end)

      {:ok, _} =
        Oracle.match_document(
          title: "Test Paper",
          author: ["Abbott, B.P.", "Abbott, R."]
        )
    end
  end
end
