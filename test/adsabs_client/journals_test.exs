defmodule ADSABSClient.JournalsTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.Journals
  alias ADSABSClient.Test.Fixtures

  describe "summary/1" do
    test "fetches journal summary by bibstem" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/journals/summary/ApJ", _opts ->
        Fixtures.ok_response(%{
          "summary" => %{
            "master" => %{
              "journal_name" => "The Astrophysical Journal",
              "bibstem" => "ApJ"
            }
          }
        })
      end)

      {:ok, result} = Journals.summary("ApJ")
      assert get_in(result, ["summary", "master", "journal_name"]) == "The Astrophysical Journal"
    end

    test "URL-encodes the bibstem" do
      expect(ADSABSClient.HTTP.Mock, :get, fn path, _opts ->
        assert path == "/journals/summary/A%26A"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Journals.summary("A&A")
    end
  end

  describe "journal/1" do
    test "fetches full journal details" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/journals/journal/ApJ", _opts ->
        Fixtures.ok_response(%{"journal" => %{"bibstem" => "ApJ"}})
      end)

      {:ok, result} = Journals.journal("ApJ")
      assert is_map(result)
    end
  end

  describe "volume/2" do
    test "fetches specific volume info" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/journals/volume/ApJ/900", _opts ->
        Fixtures.ok_response(%{"volume" => %{"volume" => "900"}})
      end)

      {:ok, result} = Journals.volume("ApJ", "900")
      assert is_map(result)
    end
  end

  describe "by_issn/1" do
    test "fetches journal by ISSN" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/journals/issn/0004-637X", _opts ->
        Fixtures.ok_response(%{"journal" => %{"issn" => "0004-637X"}})
      end)

      {:ok, result} = Journals.by_issn("0004-637X")
      assert is_map(result)
    end
  end

  describe "holdings/1" do
    test "fetches ADS holdings for journal" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/journals/holdings/ApJ", _opts ->
        Fixtures.ok_response(%{"holdings" => []})
      end)

      {:ok, result} = Journals.holdings("ApJ")
      assert is_map(result)
    end
  end

  describe "list/1" do
    test "fetches paginated journal list" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/journals/", opts ->
        params = opts[:params]
        assert params["rows"] == 50
        assert params["start"] == 0
        Fixtures.ok_response(%{"journals" => []})
      end)

      {:ok, _} = Journals.list(rows: 50)
    end
  end
end
