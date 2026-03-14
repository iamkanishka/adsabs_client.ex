defmodule ADSABSClient.Application do
  @moduledoc """
  OTP Application entry point for ADSABSClient.

  Validates config on startup and starts the supervision tree.
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Validate config at startup — fail fast rather than at first request
    _config = ADSABSClient.Config.validate!()

    Logger.info("[ADSABSClient] Starting — base_url: #{ADSABSClient.Config.get(:base_url)}")

    children = [
      ADSABSClient.RateLimiter
    ]

    opts = [strategy: :one_for_one, name: ADSABSClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
