defmodule ADSABSClient.VisTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Vis}
  alias ADSABSClient.Test.Fixtures

  @bibcodes ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

  describe "author_network/2" do
    test "posts bibcodes and returns network data" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/vis/author-network", body, _opts ->
        assert body["bibcodes"] == @bibcodes
        Fixtures.ok_response(%{"data" => %{"nodes" => [], "links" => []}})
      end)

      {:ok, result} = Vis.author_network(@bibcodes)
      assert Map.has_key?(result["data"], "nodes")
    end

    test "returns error for empty bibcodes" do
      {:error, error} = Vis.author_network([])
      assert error.type == :validation_error
    end
  end

  describe "paper_network/2" do
    test "posts bibcodes and returns network data" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/vis/paper-network", body, _opts ->
        assert body["bibcodes"] == @bibcodes
        Fixtures.ok_response(%{"data" => %{"nodes" => [], "links" => []}})
      end)

      {:ok, result} = Vis.paper_network(@bibcodes)
      assert is_map(result)
    end

    test "returns error for empty bibcodes" do
      {:error, error} = Vis.paper_network([])
      assert error.type == :validation_error
    end
  end

  describe "word_cloud/2" do
    test "posts bibcodes and returns word data" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/vis/word-cloud", body, _opts ->
        assert body["bibcodes"] == @bibcodes
        Fixtures.ok_response(%{"words" => [%{"text" => "black hole", "size" => 42}]})
      end)

      {:ok, result} = Vis.word_cloud(@bibcodes)
      assert is_list(result["words"])
      assert hd(result["words"])["text"] == "black hole"
    end

    test "returns error for empty bibcodes" do
      {:error, error} = Vis.word_cloud([])
      assert error.type == :validation_error
    end

    test "passes num_words option" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/vis/word-cloud", body, _opts ->
        assert body["numwords"] == 50
        Fixtures.ok_response(%{"words" => []})
      end)

      {:ok, _} = Vis.word_cloud(@bibcodes, num_words: 50)
    end
  end
end
