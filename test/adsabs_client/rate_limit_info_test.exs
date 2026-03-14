defmodule ADSABSClient.RateLimitInfoTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias ADSABSClient.RateLimitInfo

  @sample_headers [
    {"x-ratelimit-limit", "5000"},
    {"x-ratelimit-remaining", "4987"},
    {"x-ratelimit-reset", "1735689600"}
  ]

  describe "from_headers/1" do
    test "parses all three rate limit headers" do
      info = RateLimitInfo.from_headers(@sample_headers)

      assert info.limit == 5000
      assert info.remaining == 4987
      assert %DateTime{} = info.reset_at
    end

    test "is case-insensitive on header names" do
      headers = [
        {"X-RateLimit-Limit", "1000"},
        {"X-RateLimit-Remaining", "500"},
        {"X-RateLimit-Reset", "1735689600"}
      ]

      info = RateLimitInfo.from_headers(headers)

      assert info.limit == 1000
      assert info.remaining == 500
    end

    test "returns nil fields when headers are missing" do
      info = RateLimitInfo.from_headers([{"content-type", "application/json"}])

      assert is_nil(info.limit)
      assert is_nil(info.remaining)
      assert is_nil(info.reset_at)
    end

    test "returns empty struct for non-list input" do
      info = RateLimitInfo.from_headers(nil)

      assert %RateLimitInfo{} = info
      assert is_nil(info.limit)
    end

    test "handles mixed-case headers" do
      headers = [{"X-Ratelimit-Remaining", "99"}]
      info = RateLimitInfo.from_headers(headers)

      assert info.remaining == 99
    end
  end

  describe "low?/2" do
    test "returns true when remaining is below threshold" do
      info = %RateLimitInfo{remaining: 50}
      assert RateLimitInfo.low?(info, 100)
    end

    test "returns false when remaining is above threshold" do
      info = %RateLimitInfo{remaining: 200}
      refute RateLimitInfo.low?(info, 100)
    end

    test "returns false when remaining is exactly at threshold" do
      info = %RateLimitInfo{remaining: 100}
      refute RateLimitInfo.low?(info, 100)
    end

    test "returns false when remaining is nil" do
      info = %RateLimitInfo{remaining: nil}
      refute RateLimitInfo.low?(info, 100)
    end
  end

  describe "exhausted?/1" do
    test "returns true when remaining is 0" do
      info = %RateLimitInfo{remaining: 0}
      assert RateLimitInfo.exhausted?(info)
    end

    test "returns false when remaining is positive" do
      info = %RateLimitInfo{remaining: 1}
      refute RateLimitInfo.exhausted?(info)
    end

    test "returns false when remaining is nil" do
      info = %RateLimitInfo{remaining: nil}
      refute RateLimitInfo.exhausted?(info)
    end
  end
end
