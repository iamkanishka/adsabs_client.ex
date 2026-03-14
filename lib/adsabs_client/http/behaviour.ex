defmodule ADSABSClient.HTTP.Behaviour do
  @moduledoc """
  Behaviour contract for the ADSABSClient HTTP layer.

  This abstraction allows the HTTP implementation to be swapped out in tests
  using `Mox`, without needing Bypass or real network calls.

  ## Testing with Mox

      # In test_helper.exs or test support:
      Mox.defmock(ADSABSClient.HTTP.Mock, for: ADSABSClient.HTTP.Behaviour)
      Application.put_env(:adsabs_client, :http_client, ADSABSClient.HTTP.Mock)

      # In your test:
      import Mox
      expect(ADSABSClient.HTTP.Mock, :get, fn path, _opts ->
        {:ok, %{status: 200, headers: [], body: %{"response" => %{"docs" => []}}}}
      end)
  """

  @type response :: %{
          status: non_neg_integer(),
          headers: list({String.t(), String.t()}),
          body: map() | String.t()
        }

  @type result :: {:ok, response()} | {:error, term()}

  @callback get(path :: String.t(), opts :: keyword()) :: result()
  @callback post(path :: String.t(), body :: map(), opts :: keyword()) :: result()
  @callback delete(path :: String.t(), opts :: keyword()) :: result()
  @callback put(path :: String.t(), body :: map(), opts :: keyword()) :: result()
end
