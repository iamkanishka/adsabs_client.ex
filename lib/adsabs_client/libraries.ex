defmodule ADSABSClient.Libraries do
  @moduledoc """
  ADS Libraries API — `/biblib/*`.

  Private libraries let ADS users curate named collections of papers.
  This module covers full CRUD operations, document management,
  permissions, and set operations between libraries.

  ## Examples

      # List all your libraries
      {:ok, libraries} = ADSABSClient.Libraries.list()

      # Create a library
      {:ok, lib} = ADSABSClient.Libraries.create("My Reading List",
        description: "Papers I want to read",
        public: false
      )

      # Add documents
      {:ok, _} = ADSABSClient.Libraries.add_documents(lib.id, ["2016PhRvL.116f1102A"])

      # View contents
      {:ok, lib_with_docs} = ADSABSClient.Libraries.get(lib.id)

      # Delete library
      {:ok, _} = ADSABSClient.Libraries.delete(lib.id)
  """

  alias ADSABSClient.{Error, HTTP}
  alias ADSABSClient.Libraries.Library

  @type library_id :: String.t()
  @type bibcodes :: [String.t()]

  @doc """
  List all libraries owned by or shared with the authenticated user.

  Returns a list of `Library` structs (without bibcodes).
  To get a library's documents, use `get/1`.

  ## Example

      {:ok, [%Library{id: id, name: "My Papers"} | _]} = ADSABSClient.Libraries.list()
  """
  @spec list(keyword()) :: {:ok, [Library.t()]} | {:error, Error.t()}
  def list(_opts \\ []) do
    with {:ok, resp} <- HTTP.client().get("/biblib/libraries", []) do
      libraries =
        resp.body
        |> Map.get("libraries", [])
        |> Enum.map(&Library.from_map/1)

      {:ok, libraries}
    end
  end

  @doc """
  Get a library by ID, including its bibcodes.

  ## Options

  - `:rows` — max documents to return (default: all)
  - `:start` — document offset
  - `:sort` — sort expression

  ## Example

      {:ok, library} = ADSABSClient.Libraries.get("abc123def456")
      library.bibcodes  # => ["2016PhRvL.116f1102A", ...]
  """
  @spec get(library_id(), keyword()) :: {:ok, Library.t()} | {:error, Error.t()}
  def get(id, opts \\ []) when is_binary(id) do
    params =
      %{}
      |> maybe_put("rows", opts[:rows])
      |> maybe_put("start", opts[:start])
      |> maybe_put("sort", opts[:sort])

    with {:ok, resp} <- HTTP.client().get("/biblib/libraries/#{id}", params: params) do
      library =
        resp.body
        |> Map.get("metadata", %{})
        |> Map.put("bibcodes", Map.get(resp.body, "documents", []))
        |> Library.from_map()
        |> Map.put(:id, id)

      {:ok, library}
    end
  end

  @doc """
  Create a new private library.

  ## Options

  - `:description` — library description (default: `""`)
  - `:public` — whether the library is publicly visible (default: `false`)
  - `:bibcodes` — initial list of bibcodes to add

  ## Example

      {:ok, lib} = ADSABSClient.Libraries.create("Gravitational Waves",
        description: "LIGO papers",
        public: true,
        bibcodes: ["2016PhRvL.116f1102A"]
      )
  """
  @spec create(String.t(), keyword()) :: {:ok, Library.t()} | {:error, Error.t()}
  def create(name, opts \\ []) when is_binary(name) do
    if String.trim(name) == "" do
      {:error, Error.validation_error("library name cannot be blank")}
    else
      body =
        %{"name" => name}
        |> Map.put("description", Keyword.get(opts, :description, ""))
        |> Map.put("public", Keyword.get(opts, :public, false))
        |> maybe_put("bibcode", opts[:bibcodes])

      with {:ok, resp} <- HTTP.client().post("/biblib/libraries", body, []) do
        library = Library.from_map(resp.body)
        {:ok, library}
      end
    end
  end

  @doc """
  Update a library's metadata (name, description, public flag).

  ## Example

      {:ok, _} = ADSABSClient.Libraries.update("abc123", name: "New Name", public: true)
  """
  @spec update(library_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def update(id, opts) when is_binary(id) and is_list(opts) do
    body =
      %{}
      |> maybe_put("name", opts[:name])
      |> maybe_put("description", opts[:description])
      |> maybe_put("public", opts[:public])

    with {:ok, resp} <- HTTP.client().put("/biblib/libraries/#{id}", body, []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Delete a library permanently.

  ## Example

      {:ok, _} = ADSABSClient.Libraries.delete("abc123def456")
  """
  @spec delete(library_id()) :: {:ok, map()} | {:error, Error.t()}
  def delete(id) when is_binary(id) do
    with {:ok, resp} <- HTTP.client().delete("/biblib/libraries/#{id}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Add bibcodes to an existing library.

  ## Example

      {:ok, result} = ADSABSClient.Libraries.add_documents("abc123", [
        "2016PhRvL.116f1102A",
        "2019ApJ...882L..24A"
      ])
  """
  @spec add_documents(library_id(), bibcodes()) :: {:ok, map()} | {:error, Error.t()}
  def add_documents(id, bibcodes) when is_binary(id) and is_list(bibcodes) do
    if Enum.empty?(bibcodes) do
      {:error, Error.validation_error("add_documents requires at least one bibcode")}
    else
      body = %{"bibcode" => bibcodes, "action" => "add"}

      with {:ok, resp} <- HTTP.client().post("/biblib/documents/#{id}", body, []) do
        {:ok, resp.body}
      end
    end
  end

  @doc """
  Remove bibcodes from a library.

  ## Example

      {:ok, _} = ADSABSClient.Libraries.remove_documents("abc123", ["2016PhRvL.116f1102A"])
  """
  @spec remove_documents(library_id(), bibcodes()) :: {:ok, map()} | {:error, Error.t()}
  def remove_documents(id, bibcodes) when is_binary(id) and is_list(bibcodes) do
    if Enum.empty?(bibcodes) do
      {:error, Error.validation_error("remove_documents requires at least one bibcode")}
    else
      body = %{"bibcode" => bibcodes, "action" => "remove"}

      with {:ok, resp} <- HTTP.client().post("/biblib/documents/#{id}", body, []) do
        {:ok, resp.body}
      end
    end
  end

  @doc """
  Get the permissions for a library.

  Returns a list of `%{email: ..., permissions: [...]}` maps.

  ## Example

      {:ok, perms} = ADSABSClient.Libraries.permissions("abc123")
  """
  @spec permissions(library_id()) :: {:ok, list()} | {:error, Error.t()}
  def permissions(id) when is_binary(id) do
    with {:ok, resp} <- HTTP.client().get("/biblib/permissions/#{id}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Update permissions for a user on a library.

  `permission` is one of `"read"`, `"write"`, `"admin"`, or `""` (remove).

  ## Example

      {:ok, _} = ADSABSClient.Libraries.set_permission("abc123",
        email: "user@example.com",
        permission: "read"
      )
  """
  @spec set_permission(library_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def set_permission(id, opts) when is_binary(id) do
    body = %{
      "email" => Keyword.fetch!(opts, :email),
      "permission" => Keyword.fetch!(opts, :permission)
    }

    with {:ok, resp} <- HTTP.client().post("/biblib/permissions/#{id}", body, []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Transfer ownership of a library to another ADS user.

  ## Example

      {:ok, _} = ADSABSClient.Libraries.transfer("abc123", to_email: "newowner@example.com")
  """
  @spec transfer(library_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def transfer(id, opts) when is_binary(id) do
    body = %{"email" => Keyword.fetch!(opts, :to_email)}

    with {:ok, resp} <- HTTP.client().post("/biblib/transfer/#{id}", body, []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Perform a set operation between two libraries.

  `operation` is one of: `"union"`, `"intersection"`, `"difference"`, `"copy"`, `"empty"`.

  ## Example

      # Create a union of two libraries into a third
      {:ok, _} = ADSABSClient.Libraries.operation("lib_a_id",
        operation: "union",
        libraries: ["lib_b_id"],
        name: "Union Library"
      )
  """
  @spec operation(library_id(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def operation(id, opts) when is_binary(id) do
    body =
      %{"action" => Keyword.fetch!(opts, :operation)}
      |> maybe_put("libraries", opts[:libraries])
      |> maybe_put("name", opts[:name])
      |> maybe_put("description", opts[:description])
      |> maybe_put("public", opts[:public])

    with {:ok, resp} <- HTTP.client().post("/biblib/operations/#{id}", body, []) do
      {:ok, resp.body}
    end
  end

  # --- Private ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
