defmodule ADSABSClient.Test.MockCase do
  @moduledoc """
  Shared ExUnit case template for tests that use `ADSABSClient.HTTP.Mock`.

  Automatically:
  - Sets `:http_client` to `ADSABSClient.HTTP.Mock` before each test
  - Restores the original `:http_client` config after each test
  - Calls `Mox.verify_on_exit!` for every test

  ## Usage

      defmodule ADSABSClient.MyModuleTest do
        use ADSABSClient.Test.MockCase

        # Mox verify_on_exit! is already set up — just write your expects:
        test "does something" do
          expect(ADSABSClient.HTTP.Mock, :get, fn _path, _opts ->
            Fixtures.ok_response(%{})
          end)

          {:ok, _} = MyModule.do_thing()
        end
      end
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Mox
      import ADSABSClient.Test.MockCase.Helpers
      alias ADSABSClient.Test.Fixtures

      setup :verify_on_exit!

      setup do
        original = Application.get_env(:adsabs_client, :http_client)
        original_retries = Application.get_env(:adsabs_client, :max_retries)
        Application.put_env(:adsabs_client, :http_client, ADSABSClient.HTTP.Mock)
        Application.put_env(:adsabs_client, :max_retries, 0)

        on_exit(fn ->
          case original do
            nil -> Application.delete_env(:adsabs_client, :http_client)
            val -> Application.put_env(:adsabs_client, :http_client, val)
          end

          case original_retries do
            nil -> Application.delete_env(:adsabs_client, :max_retries)
            val -> Application.put_env(:adsabs_client, :max_retries, val)
          end
        end)

        :ok
      end
    end
  end

  defmodule Helpers do
    @moduledoc "Convenience helpers for MockCase tests."

    alias ADSABSClient.HTTP.Mock, as: HTTPMock
    alias ADSABSClient.Test.Fixtures

    import Mox

    @doc """
    Stub the HTTP mock to return a successful search response for any GET to /search/query.
    """
    def stub_search(docs \\ [], opts \\ []) do
      num_found = Keyword.get(opts, :num_found, length(docs))
      next_cursor = Keyword.get(opts, :next_cursor, "*")

      stub(HTTPMock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(%{
          "response" => %{"numFound" => num_found, "start" => 0, "docs" => docs},
          "nextCursorMark" => next_cursor
        })
      end)
    end

    @doc """
    Stub the HTTP mock to return a 429 rate-limited response.
    """
    def stub_rate_limited(retry_after \\ 60) do
      stub(HTTPMock, :get, fn _path, _opts ->
        Fixtures.rate_limited_response(retry_after)
      end)

      stub(HTTPMock, :post, fn _path, _body, _opts ->
        Fixtures.rate_limited_response(retry_after)
      end)
    end
  end
end
