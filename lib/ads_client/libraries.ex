defmodule AdsClient.Libraries do
  @moduledoc """
  Libraries API for managing paper collections.
  """

  alias AdsClient.{HTTP, Library, Error}

  @spec list_libraries(keyword()) ::
    {:ok, list(Library.t())} | {:error, Error.t()}
  def list_libraries(opts \\ []) do
    case HTTP.get("/biblib/libraries", opts) do
      {:ok, %{body: %{"libraries" => libraries}}} ->
        {:ok, Enum.map(libraries, &Library.from_api/1)}
      {:error, _} = error ->
        error
    end
  end

  @spec get_library(String.t(), keyword()) ::
    {:ok, Library.t()} | {:error, Error.t()}
  def get_library(library_id, opts \\ []) do
    case HTTP.get("/biblib/libraries/#{library_id}", opts) do
      {:ok, %{body: library}} ->
        {:ok, Library.from_api(library)}
      {:error, _} = error ->
        error
    end
  end

  @spec create_library(String.t(), String.t(), keyword()) ::
    {:ok, Library.t()} | {:error, Error.t()}
  def create_library(name, description, opts \\ []) do
    body = %{
      "name" => name,
      "description" => description,
      "public" => Keyword.get(opts, :public, false),
      "bibcode" => Keyword.get(opts, :bibcodes, [])
    }

    case HTTP.post("/biblib/libraries", body: body) do
      {:ok, %{body: library}} ->
        {:ok, Library.from_api(library)}
      {:error, _} = error ->
        error
    end
  end

  @spec add_documents(String.t(), list(String.t()), keyword()) ::
    {:ok, map()} | {:error, Error.t()}
  def add_documents(library_id, bibcodes, opts \\ []) do
    body = %{
      "bibcode" => bibcodes,
      "action" => "add"
    }

    case HTTP.post("/biblib/documents/#{library_id}", body: body) do
      {:ok, %{body: response}} ->
        {:ok, response}
      {:error, _} = error ->
        error
    end
  end

  @spec remove_documents(String.t(), list(String.t()), keyword()) ::
    {:ok, map()} | {:error, Error.t()}
  def remove_documents(library_id, bibcodes, opts \\ []) do
    body = %{
      "bibcode" => bibcodes,
      "action" => "remove"
    }

    case HTTP.post("/biblib/documents/#{library_id}", body: body) do
      {:ok, %{body: response}} ->
        {:ok, response}
      {:error, _} = error ->
        error
    end
  end

  @spec delete_library(String.t(), keyword()) ::
    {:ok, map()} | {:error, Error.t()}
  def delete_library(library_id, opts \\ []) do
    case HTTP.delete("/biblib/libraries/#{library_id}", opts) do
      {:ok, %{body: response}} ->
        {:ok, response}
      {:error, _} = error ->
        error
    end
  end
end

defmodule AdsClient.Library do
  @moduledoc """
  Library struct representing an ADS library.
  """

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    description: String.t(),
    num_documents: integer(),
    date_created: String.t(),
    date_last_modified: String.t(),
    permission: String.t(),
    public: boolean(),
    owner: String.t()
  }

  defstruct [
    :id,
    :name,
    :description,
    :num_documents,
    :date_created,
    :date_last_modified,
    :permission,
    :public,
    :owner
  ]

  def from_api(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      description: data["description"],
      num_documents: data["num_documents"],
      date_created: data["date_created"],
      date_last_modified: data["date_last_modified"],
      permission: data["permission"],
      public: data["public"],
      owner: data["owner"]
    }
  end
end
