defmodule ADSABSClient.Accounts do
  @moduledoc """
  ADS Accounts API — token validation and rate limit status.

  ## Examples

      # Check token validity and get current rate limit status
      {:ok, status} = ADSABSClient.Accounts.status()
      status["anonymous"]   # false if token is valid
  """

  alias ADSABSClient.{Error, HTTP}

  @doc """
  Check the authentication status and remaining rate limit for the configured token.

  Returns account info and current rate limit state.

  ## Example

      {:ok, status} = ADSABSClient.Accounts.status()
  """
  @spec status() :: {:ok, map()} | {:error, Error.t()}
  def status do
    with {:ok, resp} <- HTTP.client().get("/search/query", params: %{"q" => "*:*", "rows" => 0, "fl" => "id"}) do
      rate_info = ADSABSClient.RateLimitInfo.from_headers(resp.headers)

      {:ok,
       %{
         authenticated: true,
         rate_limit: rate_info
       }}
    end
  end

  @doc """
  Validate the configured API token by making a minimal request.

  Returns `:ok` if the token is valid, or `{:error, error}` if not.

  ## Example

      :ok = ADSABSClient.Accounts.validate_token!()
  """
  @spec validate_token() :: :ok | {:error, Error.t()}
  def validate_token do
    case status() do
      {:ok, _} -> :ok
      {:error, %Error{type: :unauthorized} = err} -> {:error, err}
      {:error, err} -> {:error, err}
    end
  end
end
