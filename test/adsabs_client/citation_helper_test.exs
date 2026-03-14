defmodule ADSABSClient.CitationHelperTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{CitationHelper, Error}
  alias ADSABSClient.Test.Fixtures

  describe "suggest/1" do
    test "posts to /citation_helper with bibcodes" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/citation_helper", body, _opts ->
        assert body["bibcodes"] == ["2016PhRvL.116f1102A"]
        Fixtures.ok_response(%{"results" => [%{"bibcode" => "2019ApJ...882L..24A", "score" => 0.95}]})
      end)

      {:ok, result} = CitationHelper.suggest(references: ["2016PhRvL.116f1102A"])
      assert is_list(result["results"])
    end

    test "includes title when provided" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/citation_helper", body, _opts ->
        assert Map.has_key?(body, "title")
        assert body["title"] == "My Paper"
        Fixtures.ok_response(%{"results" => []})
      end)

      {:ok, _} =
        CitationHelper.suggest(
          references: ["2016PhRvL.116f1102A"],
          title: "My Paper"
        )
    end

    test "includes abstract when provided" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/citation_helper", body, _opts ->
        assert Map.has_key?(body, "abstract")
        Fixtures.ok_response(%{"results" => []})
      end)

      {:ok, _} =
        CitationHelper.suggest(
          references: ["2016PhRvL.116f1102A"],
          abstract: "We study gravitational waves..."
        )
    end

    test "returns validation error for empty references" do
      {:error, error} = CitationHelper.suggest(references: [])
      assert error.type == :validation_error
    end

    test "returns validation error when references not provided" do
      {:error, error} = CitationHelper.suggest([])
      assert error.type == :validation_error
    end
  end
end
