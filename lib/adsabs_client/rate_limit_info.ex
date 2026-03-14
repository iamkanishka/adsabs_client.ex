defmodule ADSABSClient.RateLimitInfo do
  @moduledoc """
  Parsed rate-limit metadata from ADS API response headers.

  ADS advertises rate limits on every response:

      X-RateLimit-Limit: 5000
      X-RateLimit-Remaining: 4987
      X-RateLimit-Reset: 1_435_190_400

  This struct is attached to every successful response so consumers can
  monitor their quota usage without an extra API call.
  """

  @type t :: %__MODULE__{
          limit: non_neg_integer() | nil,
          remaining: non_neg_integer() | nil,
          reset_at: DateTime.t() | nil
        }

  defstruct [:limit, :remaining, :reset_at]

  @doc "Parse rate-limit headers from a Req response."
  @spec from_headers(list({String.t(), String.t()})) :: t()
  def from_headers(headers) when is_list(headers) do
    headers_map =
      Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)

    %__MODULE__{
      limit: parse_int(headers_map["x-ratelimit-limit"]),
      remaining: parse_int(headers_map["x-ratelimit-remaining"]),
      reset_at: parse_timestamp(headers_map["x-ratelimit-reset"])
    }
  end

  def from_headers(_), do: %__MODULE__{}

  @doc "Returns true if remaining requests is below a warning threshold."
  @spec low?(t(), non_neg_integer()) :: boolean()
  def low?(%__MODULE__{remaining: nil}, _threshold), do: false
  def low?(%__MODULE__{remaining: remaining}, threshold), do: remaining < threshold

  @doc "Returns true if the rate limit is exhausted."
  @spec exhausted?(t()) :: boolean()
  def exhausted?(%__MODULE__{remaining: nil}), do: false
  def exhausted?(%__MODULE__{remaining: 0}), do: true
  def exhausted?(_), do: false

  # --- Private ---

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_list(val), do: parse_int(List.first(val))

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(val) when is_list(val), do: parse_timestamp(List.first(val))

  defp parse_timestamp(val) when is_binary(val) do
    case Integer.parse(val) do
      {unix, _} -> DateTime.from_unix!(unix)
      :error -> nil
    end
  end

  defp parse_timestamp(_), do: nil
end
