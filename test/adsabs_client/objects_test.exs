defmodule ADSABSClient.ObjectsTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Objects}
  alias ADSABSClient.Test.Fixtures

  describe "resolve/1" do
    test "fetches canonical identifier for an object name" do
      expect(ADSABSClient.HTTP.Mock, :get, fn path, _opts ->
        assert path =~ "/objects/"
        assert path =~ "Andromeda"
        Fixtures.ok_response(%{"Andromeda Galaxy" => "M31"})
      end)

      {:ok, result} = Objects.resolve("Andromeda Galaxy")
      assert result["Andromeda Galaxy"] == "M31"
    end

    test "URL-encodes the object name" do
      expect(ADSABSClient.HTTP.Mock, :get, fn path, _opts ->
        assert path =~ "Sgr%20A%2A"
        Fixtures.ok_response(%{"Sgr A*" => "Sgr A*"})
      end)

      {:ok, _} = Objects.resolve("Sgr A*")
    end

    test "handles 404 for unknown objects" do
      expect(ADSABSClient.HTTP.Mock, :get, fn _path, _opts ->
        Fixtures.error_response(404)
      end)

      {:error, %Error{type: :not_found}} = Objects.resolve("not_a_real_object_xyz")
    end
  end

  describe "query/2" do
    test "queries by object name" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/objects/query", opts ->
        assert opts[:params]["query"] == "M31"
        Fixtures.ok_response(%{"objects" => [%{"canonical" => "M31", "type" => "Galaxy"}]})
      end)

      {:ok, result} = Objects.query("M31")
      assert is_map(result)
    end

    test "passes source parameter when provided" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/objects/query", opts ->
        assert opts[:params]["source"] == "simbad"
        Fixtures.ok_response(%{"objects" => []})
      end)

      {:ok, _} = Objects.query("Crab Nebula", source: "simbad")
    end

    test "does not include source when not provided" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/objects/query", opts ->
        refute Map.has_key?(opts[:params] || %{}, "source")
        Fixtures.ok_response(%{"objects" => []})
      end)

      {:ok, _} = Objects.query("M87")
    end
  end

  describe "resolve_many/2" do
    test "posts a list of object names" do
      object_names = ["M31", "Crab Nebula", "NGC 1234"]

      expect(ADSABSClient.HTTP.Mock, :post, fn "/objects", body, _opts ->
        assert body["objects"] == object_names

        Fixtures.ok_response(%{
          "M31" => "M31",
          "Crab Nebula" => "M1",
          "NGC 1234" => "NGC 1234"
        })
      end)

      {:ok, result} = Objects.resolve_many(object_names)

      assert result["Crab Nebula"] == "M1"
      assert result["M31"] == "M31"
    end

    test "returns validation error for empty list" do
      {:error, error} = Objects.resolve_many([])
      assert error.type == :validation_error
      assert error.message =~ "at least one"
    end

    test "passes source option when provided" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/objects", body, _opts ->
        assert body["source"] == "ned"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Objects.resolve_many(["M31"], source: "ned")
    end
  end
end
