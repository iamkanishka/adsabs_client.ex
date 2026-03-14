defmodule ADSABSClient.Objects do
  @moduledoc """
  ADS Objects API — `/objects/*`.

  Resolves astronomical object names (via SIMBAD and NED) and performs
  position-based queries.

  ## Examples

      # Resolve an object name to a canonical identifier
      {:ok, result} = ADSABSClient.Objects.resolve("Andromeda Galaxy")

      # Get canonical name for an object
      {:ok, result} = ADSABSClient.Objects.query("M31")

      # Search by object names across multiple objects
      {:ok, result} = ADSABSClient.Objects.resolve_many(["M31", "NGC 1234", "Crab Nebula"])
  """

  alias ADSABSClient.{Error, HTTP}

  @doc """
  Resolve a single object name to its canonical identifiers.

  ## Example

      {:ok, result} = ADSABSClient.Objects.resolve("Sgr A*")
  """
  @spec resolve(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(object_name) when is_binary(object_name) do
    with {:ok, resp} <- HTTP.client().get("/objects/#{URI.encode(object_name)}", []) do
      {:ok, resp.body}
    end
  end

  @doc """
  Query objects by name, returning canonical identifiers and positions.

  ## Example

      {:ok, result} = ADSABSClient.Objects.query("M87", source: "simbad")
  """
  @spec query(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def query(object_name, opts \\ []) when is_binary(object_name) do
    params =
      %{"query" => object_name}
      |> maybe_put("source", opts[:source])

    with {:ok, resp} <- HTTP.client().get("/objects/query", params: params) do
      {:ok, resp.body}
    end
  end

  @doc """
  Resolve multiple object names in a single request.

  ## Example

      {:ok, result} = ADSABSClient.Objects.resolve_many(["M31", "Crab Nebula"])
      # Returns a map from object name => canonical identifier
  """
  @spec resolve_many([String.t()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def resolve_many(object_names, opts \\ []) when is_list(object_names) do
    if Enum.empty?(object_names) do
      {:error, Error.validation_error("resolve_many requires at least one object name")}
    else
      body =
        %{"objects" => object_names}
        |> maybe_put("source", opts[:source])

      with {:ok, resp} <- HTTP.client().post("/objects", body, []) do
        {:ok, resp.body}
      end
    end
  end

  # --- Private ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
