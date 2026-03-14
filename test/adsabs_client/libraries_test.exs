defmodule ADSABSClient.LibrariesTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Libraries}
  alias ADSABSClient.Libraries.Library
  alias ADSABSClient.Test.Fixtures

  describe "list/1" do
    test "returns a list of Library structs" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/biblib/libraries", _opts ->
        Fixtures.ok_response(Fixtures.library_list_response_body())
      end)

      {:ok, libraries} = Libraries.list()

      assert is_list(libraries)
      assert length(libraries) == 1
      assert %Library{} = hd(libraries)
    end

    test "parses library fields correctly" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/biblib/libraries", _opts ->
        Fixtures.ok_response(Fixtures.library_list_response_body())
      end)

      {:ok, [lib]} = Libraries.list()

      assert lib.id == "abc123"
      assert lib.name == "My Papers"
      assert lib.description == "Papers I like"
      assert lib.num_documents == 5
      assert lib.public == false
      assert lib.permission == "owner"
    end

    test "returns empty list when no libraries exist" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/biblib/libraries", _opts ->
        Fixtures.ok_response(%{"libraries" => []})
      end)

      {:ok, libs} = Libraries.list()
      assert libs == []
    end
  end

  describe "get/2" do
    test "returns library with bibcodes" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/biblib/libraries/abc123", _opts ->
        Fixtures.ok_response(%{
          "metadata" => %{
            "name" => "My Papers",
            "description" => "desc",
            "num_documents" => 2,
            "permission" => "owner",
            "public" => false
          },
          "documents" => ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]
        })
      end)

      {:ok, lib} = Libraries.get("abc123")

      assert lib.id == "abc123"
      assert length(lib.bibcodes) == 2
      assert "2016PhRvL.116f1102A" in lib.bibcodes
    end

    test "handles library with no documents" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/biblib/libraries/empty_lib", _opts ->
        Fixtures.ok_response(%{
          "metadata" => %{"name" => "Empty", "num_documents" => 0, "permission" => "owner", "public" => false},
          "documents" => []
        })
      end)

      {:ok, lib} = Libraries.get("empty_lib")
      assert lib.bibcodes == []
    end
  end

  describe "create/2" do
    test "creates library with name and description" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/libraries", body, _opts ->
        assert body["name"] == "Test Library"
        assert body["description"] == "A test"
        assert body["public"] == false
        Fixtures.ok_response(%{"id" => "new_lib_id", "name" => "Test Library"})
      end)

      {:ok, lib} = Libraries.create("Test Library", description: "A test")
      assert lib.id == "new_lib_id"
    end

    test "returns validation error for blank name" do
      {:error, error} = Libraries.create("")
      assert error.type == :validation_error
      assert error.message =~ "blank"
    end

    test "returns validation error for whitespace-only name" do
      {:error, error} = Libraries.create("   ")
      assert error.type == :validation_error
    end

    test "creates public library when public: true" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/libraries", body, _opts ->
        assert body["public"] == true
        Fixtures.ok_response(%{"id" => "pub_lib", "name" => "Public"})
      end)

      {:ok, _} = Libraries.create("Public", public: true)
    end

    test "includes initial bibcodes when provided" do
      bibcodes = ["2016PhRvL.116f1102A"]

      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/libraries", body, _opts ->
        assert body["bibcode"] == bibcodes
        Fixtures.ok_response(%{"id" => "lib1", "name" => "With Docs"})
      end)

      {:ok, _} = Libraries.create("With Docs", bibcodes: bibcodes)
    end
  end

  describe "update/2" do
    test "sends PUT to correct libraries path" do
      expect(ADSABSClient.HTTP.Mock, :put, fn path, body, _opts ->
        assert path == "/biblib/libraries/abc123"
        assert body["name"] == "Renamed Library"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Libraries.update("abc123", name: "Renamed Library")
    end

    test "allows updating description independently" do
      expect(ADSABSClient.HTTP.Mock, :put, fn "/biblib/libraries/abc123", body, _opts ->
        assert body["description"] == "New description"
        refute Map.has_key?(body, "name")
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Libraries.update("abc123", description: "New description")
    end

    test "can set public flag" do
      expect(ADSABSClient.HTTP.Mock, :put, fn "/biblib/libraries/abc123", body, _opts ->
        assert body["public"] == true
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Libraries.update("abc123", public: true)
    end
  end

  describe "delete/1" do
    test "sends DELETE to correct path" do
      expect(ADSABSClient.HTTP.Mock, :delete, fn "/biblib/libraries/abc123", _opts ->
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Libraries.delete("abc123")
    end
  end

  describe "add_documents/2" do
    test "posts add action with bibcodes" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/documents/abc123", body, _opts ->
        assert body["action"] == "add"
        assert body["bibcode"] == ["2016PhRvL.116f1102A"]
        Fixtures.ok_response(%{"number_added" => 1})
      end)

      {:ok, result} = Libraries.add_documents("abc123", ["2016PhRvL.116f1102A"])
      assert result["number_added"] == 1
    end

    test "returns validation error for empty bibcodes" do
      {:error, error} = Libraries.add_documents("abc123", [])
      assert error.type == :validation_error
    end
  end

  describe "remove_documents/2" do
    test "posts remove action with bibcodes" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/documents/abc123", body, _opts ->
        assert body["action"] == "remove"
        assert body["bibcode"] == ["2016PhRvL.116f1102A"]
        Fixtures.ok_response(%{"number_removed" => 1})
      end)

      {:ok, _} = Libraries.remove_documents("abc123", ["2016PhRvL.116f1102A"])
    end

    test "returns validation error for empty bibcodes" do
      {:error, error} = Libraries.remove_documents("abc123", [])
      assert error.type == :validation_error
    end
  end

  describe "permissions/1" do
    test "fetches library permissions" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/biblib/permissions/abc123", _opts ->
        Fixtures.ok_response([%{"email" => "user@example.com", "permissions" => ["read"]}])
      end)

      {:ok, perms} = Libraries.permissions("abc123")
      assert is_list(perms)
    end
  end

  describe "set_permission/2" do
    test "posts permission update" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/permissions/abc123", body, _opts ->
        assert body["email"] == "collab@example.com"
        assert body["permission"] == "read"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Libraries.set_permission("abc123", email: "collab@example.com", permission: "read")
    end
  end

  describe "transfer/2" do
    test "posts transfer request" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/transfer/abc123", body, _opts ->
        assert body["email"] == "newowner@example.com"
        Fixtures.ok_response(%{})
      end)

      {:ok, _} = Libraries.transfer("abc123", to_email: "newowner@example.com")
    end
  end

  describe "operation/2" do
    test "posts union operation" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/biblib/operations/lib_a", body, _opts ->
        assert body["action"] == "union"
        assert body["libraries"] == ["lib_b"]
        Fixtures.ok_response(%{"name" => "Union Result"})
      end)

      {:ok, _} =
        Libraries.operation("lib_a",
          operation: "union",
          libraries: ["lib_b"],
          name: "Union Result"
        )
    end
  end

  describe "Library.from_map/1" do
    test "populates all fields from map" do
      data = %{
        "id" => "lib1",
        "name" => "Test",
        "description" => "Desc",
        "num_documents" => 10,
        "date_created" => "2024-01-01T00:00:00",
        "date_last_modified" => "2024-06-01T00:00:00",
        "permission" => "write",
        "public" => true,
        "owner" => "owner@example.com"
      }

      lib = Library.from_map(data)

      assert lib.id == "lib1"
      assert lib.name == "Test"
      assert lib.num_documents == 10
      assert lib.permission == "write"
      assert lib.public == true
      assert lib.owner == "owner@example.com"
    end

    test "uses defaults for missing keys" do
      lib = Library.from_map(%{})

      assert lib.name == ""
      assert lib.num_documents == 0
      assert lib.public == false
      assert lib.bibcodes == []
    end
  end
end
