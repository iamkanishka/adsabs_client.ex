defmodule AdsClient.Error do
  @moduledoc """
  Error struct for ADS API errors.

  ## Error Types

    * `:network` - Network/connection errors
    * `:rate_limit` - Rate limit exceeded (HTTP 429)
    * `:api` - API errors (HTTP 4xx)
    * `:server` - Server errors (HTTP 5xx)
    * `:parse` - Response parsing errors
    * `:validation` - Request validation errors
  """

  @type error_type :: :network | :rate_limit | :api | :server | :parse | :validation

  @type t :: %__MODULE__{
    type: error_type(),
    message: String.t(),
    status: integer() | nil,
    body: any(),
    details: map()
  }

  defexception [:type, :message, :status, :body, :details]

  def new(type, message, opts \\ []) do
    %__MODULE__{
      type: type,
      message: message,
      status: Keyword.get(opts, :status),
      body: Keyword.get(opts, :body),
      details: Keyword.get(opts, :details, %{})
    }
  end

  @impl true
  def exception(attrs) do
    struct!(__MODULE__, attrs)
  end

  @impl true
  def message(%__MODULE__{type: type, message: message, status: status}) do
    status_part = if status, do: " (HTTP #{status})", else: ""
    "[#{type}]#{status_part} #{message}"
  end
end
