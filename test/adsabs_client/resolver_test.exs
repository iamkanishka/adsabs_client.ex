defmodule ADSABSClient.ResolverTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Resolver}
  alias ADSABSClient.Test.Fixtures

  @bibcode "2016PhRvL.116f1102A"

  describe "resolve/1" do
    test "fetches all links for a bibcode" do
      expect(ADSABSClient.HTTP.Mock, :get, fn path, _opts ->
        assert path == "/resolver/#{URI.encode(@bibcode)}"
        Fixtures.ok_response(%{"links" => %{"count" => 5}})
      end)

      {:ok, result} = Resolver.resolve(@bibcode)
      assert result["links"]["count"] == 5
    end
  end

  describe "resolve/2 with link type" do
    test "fetches a specific link type" do
      expect(ADSABSClient.HTTP.Mock, :get, fn path, _opts ->
        assert path =~ "/full"

        Fixtures.ok_response(%{
          "resolved" => %{
            "url" => "https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.116.061102",
            "bibcode" => @bibcode
          }
        })
      end)

      {:ok, result} = Resolver.resolve(@bibcode, :full)
      assert result["resolved"]["url"] =~ "journals.aps.org"
    end

    test "returns validation error for invalid link type" do
      {:error, error} = Resolver.resolve(@bibcode, :invalid_type)
      assert error.type == :validation_error
      assert error.message =~ "Invalid link type"
    end

    test "accepts all valid link types" do
      valid_types = ~w(abstract citations references full preprint data graphics esource associated metrics similar)a

      Enum.each(valid_types, fn type ->
        expect(ADSABSClient.HTTP.Mock, :get, fn _path, _opts ->
          Fixtures.ok_response(%{"resolved" => %{}})
        end)

        assert {:ok, _} = Resolver.resolve(@bibcode, type)
      end)
    end

    test "accepts string link types" do
      expect(ADSABSClient.HTTP.Mock, :get, fn _path, _opts ->
        Fixtures.ok_response(%{"resolved" => %{"url" => "https://arxiv.org/abs/1602.03837"}})
      end)

      assert {:ok, _} = Resolver.resolve(@bibcode, "preprint")
    end
  end

  describe "full_text_url/1" do
    test "returns URL string on success" do
      expect(ADSABSClient.HTTP.Mock, :get, fn _path, _opts ->
        Fixtures.ok_response(%{
          "resolved" => %{"url" => "https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.116.061102"}
        })
      end)

      {:ok, url} = Resolver.full_text_url(@bibcode)
      assert url =~ "https://"
    end

    test "returns error when no URL in response" do
      expect(ADSABSClient.HTTP.Mock, :get, fn _path, _opts ->
        Fixtures.ok_response(%{"resolved" => %{}})
      end)

      {:error, _error} = Resolver.full_text_url(@bibcode)
    end
  end

  describe "preprint_url/1" do
    test "returns arXiv URL" do
      expect(ADSABSClient.HTTP.Mock, :get, fn _path, _opts ->
        Fixtures.ok_response(%{
          "resolved" => %{"url" => "https://arxiv.org/abs/1602.03837"}
        })
      end)

      {:ok, url} = Resolver.preprint_url(@bibcode)
      assert url =~ "arxiv.org"
    end
  end
end
