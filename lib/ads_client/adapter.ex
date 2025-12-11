defmodule AdsClient.Adapter do
  @moduledoc """
  Behaviour for HTTP adapters.

  Allows swapping HTTP clients for testing and flexibility.
  """

  @type method :: :get | :post | :put | :delete
  @type url :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type body :: map() | String.t() | nil
  @type opts :: keyword()
  @type response :: %{status: integer(), body: any(), headers: headers()}

  @callback request(method(), url(), headers(), body(), opts()) ::
    {:ok, response()} | {:error, AdsClient.Error.t()}
end
