defmodule AdsabsClient.Config do
  @moduledoc false

  @type t :: %__MODULE__{
    api_token: String.t() | nil,
    adapter: module(),
    base_url: String.t(),
    default_timeout: integer(),
    max_retries: integer(),
    retry_delay: integer(),
    backoff_multiplier: float(),
    jitter: float()
  }

  defstruct [
    :api_token,
    :adapter,
    :base_url,
    :default_timeout,
    :max_retries,
    :retry_delay,
    :backoff_multiplier,
    :jitter
  ]

  def get do
    %__MODULE__{
      api_token: Application.get_env(:adsabs_client, :api_token),
      adapter: Application.get_env(:adsabs_client, :adapter, AdsabsClient.Adapter.Req),
      base_url: Application.get_env(:adsabs_client, :base_url, "https://api.adsabs.harvard.edu/v1"),
      default_timeout: Application.get_env(:adsabs_client, :default_timeout, 30_000),
      max_retries: Application.get_env(:adsabs_client, :max_retries, 3),
      retry_delay: Application.get_env(:adsabs_client, :retry_delay, 1_000),
      backoff_multiplier: Application.get_env(:adsabs_client, :backoff_multiplier, 2.0),
      jitter: Application.get_env(:adsabs_client, :jitter, 0.1)
    }
  end

  def validate!(%__MODULE__{api_token: nil}) do
    raise ArgumentError, """
    ADS API token not configured. Please set:
      config :adsabs_client, api_token: "your_token"
    Or set the ADS_API_TOKEN environment variable.
    Get your token at: https://ui.adsabs.harvard.edu/user/settings/token
    """
  end
  def validate!(config), do: config
end
