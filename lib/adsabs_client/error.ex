defmodule ADSABSClient.Error do
  @moduledoc """
  Structured error type for all ADSABSClient operations.

  Every public function in this library returns either `{:ok, result}` or
  `{:error, %ADSABSClient.Error{}}` — never raw HTTPoison or Req errors.

  ## Error Types

  | Type | HTTP Status | Meaning |
  |---|---|---|
  | `:unauthorized` | 401 | Invalid or missing API token |
  | `:forbidden` | 403 | Token valid but lacks permission |
  | `:not_found` | 404 | Resource does not exist |
  | `:rate_limited` | 429 | Daily or per-minute quota exceeded |
  | `:server_error` | 5xx | ADS server-side error |
  | `:network_error` | nil | Timeout or connection refused |
  | `:decode_error` | nil | Unexpected response body format |
  | `:validation_error` | nil | Invalid input parameters |

  ## Example

      case ADSABSClient.Search.query("black holes") do
        {:ok, response} -> process(response)
        {:error, %ADSABSClient.Error{type: :rate_limited, retry_after: secs}} ->
          :timer.sleep(secs * 1000)
          # retry...
        {:error, %ADSABSClient.Error{type: :unauthorized}} ->
          raise "Check your ADS_API_TOKEN environment variable"
        {:error, error} ->
          Logger.error("ADS request failed: \#{error.message}")
      end
  """

  @type error_type ::
          :unauthorized
          | :forbidden
          | :not_found
          | :rate_limited
          | :server_error
          | :network_error
          | :decode_error
          | :validation_error

  @type t :: %__MODULE__{
          type: error_type(),
          status: non_neg_integer() | nil,
          message: String.t(),
          retry_after: non_neg_integer() | nil,
          details: map() | nil
        }

  @enforce_keys [:type, :message]
  defstruct [:type, :status, :message, :retry_after, :details]

  @doc "Build an error from an HTTP response."
  @spec from_response(map()) :: t()
  def from_response(%{status: 401} = resp) do
    %__MODULE__{
      type: :unauthorized,
      status: 401,
      message: extract_message(resp, "Unauthorized: check your ADS API token"),
      retry_after: nil,
      details: nil
    }
  end

  def from_response(%{status: 403} = resp) do
    %__MODULE__{
      type: :forbidden,
      status: 403,
      message: extract_message(resp, "Forbidden: insufficient permissions"),
      retry_after: nil,
      details: nil
    }
  end

  def from_response(%{status: 404} = resp) do
    %__MODULE__{
      type: :not_found,
      status: 404,
      message: extract_message(resp, "Not found"),
      retry_after: nil,
      details: nil
    }
  end

  def from_response(%{status: 429} = resp) do
    retry_after = parse_retry_after(resp)

    %__MODULE__{
      type: :rate_limited,
      status: 429,
      message: "Rate limit exceeded. Retry after #{retry_after} seconds.",
      retry_after: retry_after,
      details: nil
    }
  end

  def from_response(%{status: status} = resp) when status in 500..599 do
    %__MODULE__{
      type: :server_error,
      status: status,
      message: extract_message(resp, "ADS server error (#{status})"),
      retry_after: nil,
      details: nil
    }
  end

  def from_response(resp) do
    %__MODULE__{
      type: :server_error,
      status: Map.get(resp, :status),
      message: "Unexpected response: #{inspect(resp)}",
      retry_after: nil,
      details: nil
    }
  end

  @doc "Build a network error (timeout, connection refused, etc.)."
  @spec network_error(reason :: term()) :: t()
  def network_error(reason) do
    %__MODULE__{
      type: :network_error,
      status: nil,
      message: "Network error: #{inspect(reason)}",
      retry_after: nil,
      details: nil
    }
  end

  @doc "Build a JSON decode error."
  @spec decode_error(body :: String.t()) :: t()
  def decode_error(body) do
    %__MODULE__{
      type: :decode_error,
      status: nil,
      message: "Failed to decode response body",
      retry_after: nil,
      details: %{body: String.slice(body, 0, 500)}
    }
  end

  @doc "Build a not-found error."
  @spec not_found(message :: String.t()) :: t()
  def not_found(message) do
    %__MODULE__{
      type: :not_found,
      status: 404,
      message: message,
      retry_after: nil,
      details: nil
    }
  end

  @doc "Build a validation error for invalid input."
  @spec validation_error(message :: String.t()) :: t()
  def validation_error(message) do
    %__MODULE__{
      type: :validation_error,
      status: nil,
      message: message,
      retry_after: nil,
      details: nil
    }
  end

  # --- Private Helpers ---

  defp extract_message(%{body: %{"error" => msg}}, _default) when is_binary(msg), do: msg
  defp extract_message(%{body: %{"message" => msg}}, _default) when is_binary(msg), do: msg
  defp extract_message(_, default), do: default

  defp parse_retry_after(%{headers: headers}) do
    case Enum.find(headers, fn {k, _} -> String.downcase(k) == "retry-after" end) do
      {_, val} -> String.to_integer(val)
      nil -> 60
    end
  end

  defp parse_retry_after(_), do: 60
end
