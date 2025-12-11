defmodule AdsClient.Resolver do
  @moduledoc """
  Resolver API for getting links to external resources.
  """

  alias AdsClient.{HTTP, Error}

  @link_types ~w(
    abstract citations references coreads toc openurl metrics
    graphics esource data inspire librarycatalog presentation
    associated
  )a

  @spec resolve(String.t(), atom() | nil, keyword()) ::
    {:ok, map()} | {:error, Error.t()}
  def resolve(bibcode, link_type \\ nil, opts \\ []) do
    path = build_path(bibcode, link_type)

    case HTTP.get(path, opts) do
      {:ok, %{body: response}} ->
        {:ok, response}
      {:error, _} = error ->
        error
    end
  end

  @spec list_link_types() :: list(atom())
  def list_link_types, do: @link_types

  defp build_path(bibcode, nil), do: "/resolver/#{bibcode}"
  defp build_path(bibcode, link_type) when is_atom(link_type) do
    "/resolver/#{bibcode}/#{link_type}"
  end
end
