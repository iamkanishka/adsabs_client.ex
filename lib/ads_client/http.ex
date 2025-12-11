defmodule AdsClient.HTTP do
  @moduledoc false

  alias AdsClient.{Config, Error}

  def request(method, path, opts \\ []) do
    config = Config.get() |> Config.validate!()
    adapter = config.adapter

    url = build_url(config.base_url, path, opts[:query])
    headers = build_headers(config.api_token, opts[:headers])
    body = opts[:body]

    adapter.request(method, url, headers, body, opts)
  end

  def get(path, opts \\ []), do: request(:get, path, opts)
  def post(path, opts \\ []), do: request(:post, path, opts)
  def put(path, opts \\ []), do: request(:put, path, opts)
  def delete(path, opts \\ []), do: request(:delete, path, opts)

  defp build_url(base_url, path, nil), do: "#{base_url}#{path}"
  defp build_url(base_url, path, query) do
    query_string = URI.encode_query(query)
    "#{base_url}#{path}?#{query_string}"
  end

  defp build_headers(token, custom_headers \\ []) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ] ++ (custom_headers || [])
  end
end
