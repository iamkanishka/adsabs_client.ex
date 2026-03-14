defmodule ADSABSClient.AccountsTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Accounts, Error, RateLimitInfo}
  alias ADSABSClient.Test.Fixtures

  describe "status/0" do
    test "returns authenticated status with rate limit info on success" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(
          Fixtures.search_response_body(),
          Fixtures.rate_limit_headers()
        )
      end)

      {:ok, status} = Accounts.status()

      assert status.authenticated == true
      assert %RateLimitInfo{} = status.rate_limit
    end

    test "returns error on 401 (invalid token)" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.error_response(401, "Unauthorized")
      end)

      {:error, error} = Accounts.status()
      assert error.type == :unauthorized
    end

    test "returns error on network failure" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        {:error, %{reason: :econnrefused}}
      end)

      {:error, error} = Accounts.status()
      assert error.type == :network_error
    end

    test "makes request with rows=0 to avoid fetching documents" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", opts ->
        params = opts[:params] || %{}
        assert params["rows"] == 0
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      {:ok, _} = Accounts.status()
    end
  end

  describe "validate_token/0" do
    test "returns :ok when token is valid" do
      expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.ok_response(Fixtures.search_response_body())
      end)

      assert :ok = Accounts.validate_token()
    end

    test "returns error when token is invalid" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.error_response(401)
      end)

      assert {:error, %Error{type: :unauthorized}} = Accounts.validate_token()
    end

    test "returns error on server failure" do
      stub(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
        Fixtures.error_response(503)
      end)

      {:error, error} = Accounts.validate_token()
      assert error.type in [:server_error, :network_error, :unauthorized]
    end
  end
end
