defmodule ADSABSClient.ErrorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ADSABSClient.Error

  describe "from_response/1" do
    test "builds :unauthorized error for 401" do
      resp = %{status: 401, headers: [], body: %{"error" => "Unauthorized"}}
      error = Error.from_response(resp)

      assert error.type == :unauthorized
      assert error.status == 401
      assert error.message == "Unauthorized"
      assert is_nil(error.retry_after)
    end

    test "builds :forbidden error for 403" do
      resp = %{status: 403, headers: [], body: %{}}
      error = Error.from_response(resp)

      assert error.type == :forbidden
      assert error.status == 403
    end

    test "builds :not_found error for 404" do
      resp = %{status: 404, headers: [], body: %{}}
      error = Error.from_response(resp)

      assert error.type == :not_found
      assert error.status == 404
    end

    test "builds :rate_limited error for 429 with Retry-After header" do
      resp = %{
        status: 429,
        headers: [{"retry-after", "120"}],
        body: %{"error" => "Too Many Requests"}
      }

      error = Error.from_response(resp)

      assert error.type == :rate_limited
      assert error.status == 429
      assert error.retry_after == 120
      assert error.message =~ "120 seconds"
    end

    test "defaults retry_after to 60 when header missing on 429" do
      resp = %{status: 429, headers: [], body: %{}}
      error = Error.from_response(resp)

      assert error.retry_after == 60
    end

    test "builds :server_error for 500" do
      resp = %{status: 500, headers: [], body: %{}}
      error = Error.from_response(resp)

      assert error.type == :server_error
      assert error.status == 500
    end

    test "builds :server_error for 503" do
      resp = %{status: 503, headers: [], body: %{}}
      error = Error.from_response(resp)

      assert error.type == :server_error
    end

    test "extracts message from body 'message' key" do
      resp = %{status: 401, headers: [], body: %{"message" => "Token expired"}}
      error = Error.from_response(resp)

      assert error.message == "Token expired"
    end

    test "falls back to default message when body has no message" do
      resp = %{status: 401, headers: [], body: %{}}
      error = Error.from_response(resp)

      assert is_binary(error.message)
      assert String.length(error.message) > 0
    end
  end

  describe "network_error/1" do
    test "wraps reason in a network error" do
      error = Error.network_error(:econnrefused)

      assert error.type == :network_error
      assert is_nil(error.status)
      assert error.message =~ "econnrefused"
    end
  end

  describe "decode_error/1" do
    test "wraps body snippet in decode error" do
      error = Error.decode_error("not valid json{{{")

      assert error.type == :decode_error
      assert error.details.body == "not valid json{{{"
    end

    test "truncates very long bodies to 500 chars" do
      long_body = String.duplicate("x", 1000)
      error = Error.decode_error(long_body)

      assert String.length(error.details.body) == 500
    end
  end

  describe "validation_error/1" do
    test "creates validation error with given message" do
      error = Error.validation_error("bibcodes cannot be empty")

      assert error.type == :validation_error
      assert error.message == "bibcodes cannot be empty"
      assert is_nil(error.status)
    end
  end
end
