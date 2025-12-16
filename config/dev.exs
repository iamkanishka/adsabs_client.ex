import Config

config :adsabs_client,
  adapter: AdsabsClient.Adapter.Req,
  base_url: "https://api.adsabs.harvard.edu/v1",
  default_timeout: 30_000,
  max_retries: 3,
  retry_delay: 1_000,
  backoff_multiplier: 2.0,
  jitter: 0.1,
  api_token: "1rX8x3Ly32XPMXvZ7nyQIKsTjsBFbLwJrHvFAwbG"
