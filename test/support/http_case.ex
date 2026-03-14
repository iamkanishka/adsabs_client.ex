defmodule ADSABSClient.Test.HTTPCase do
  @moduledoc """
  Test case module for tests that need a real HTTP mock server via Bypass.

  ## Usage

      defmodule MyTest do
        use ADSABSClient.Test.HTTPCase

        test "fetches search results", %{bypass: bypass} do
          stub_search(bypass, body: Fixtures.search_response_body())

          {:ok, resp} = ADSABSClient.Search.query("black holes")
          assert resp.num_found == 3
        end
      end
  """

  use ExUnit.CaseTemplate

  alias ADSABSClient.Test.Fixtures
  alias Plug.Conn

  using do
    quote do
      import ADSABSClient.Test.HTTPCase
      alias ADSABSClient.Test.Fixtures
    end
  end

  setup do
    bypass = Bypass.open()
    Application.put_env(:adsabs_client, :base_url, "http://localhost:#{bypass.port}")
    on_exit(fn -> Application.put_env(:adsabs_client, :base_url, "http://localhost") end)
    {:ok, bypass: bypass}
  end

  @doc "Stub a successful search endpoint response."
  def stub_search(bypass, opts \\ []) do
    body = Keyword.get(opts, :body, Fixtures.search_response_body())
    status = Keyword.get(opts, :status, 200)

    Bypass.stub(bypass, "GET", "/search/query", fn conn ->
      conn
      |> Conn.put_resp_header("content-type", "application/json")
      |> Conn.put_resp_header("x-ratelimit-limit", "5000")
      |> Conn.put_resp_header("x-ratelimit-remaining", "4980")
      |> Conn.send_resp(status, Jason.encode!(body))
    end)
  end

  @doc "Stub a rate-limited (429) response."
  def stub_rate_limited(bypass, retry_after \\ 60) do
    Bypass.stub(bypass, "GET", "/search/query", fn conn ->
      conn
      |> Conn.put_resp_header("content-type", "application/json")
      |> Conn.put_resp_header("retry-after", "#{retry_after}")
      |> Conn.send_resp(429, Jason.encode!(%{"error" => "Too Many Requests"}))
    end)
  end

  @doc "Stub any POST endpoint."
  def stub_post(bypass, path, body, opts \\ []) do
    status = Keyword.get(opts, :status, 200)

    Bypass.stub(bypass, "POST", path, fn conn ->
      conn
      |> Conn.put_resp_header("content-type", "application/json")
      |> Conn.send_resp(status, Jason.encode!(body))
    end)
  end
end
