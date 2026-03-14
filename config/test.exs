import Config

config :adsabs_client,
  api_token: "test-token-12345",
  base_url: "http://localhost",
  connect_timeout: 1_000,
  receive_timeout: 5_000,
  max_retries: 1,
  base_backoff_ms: 10,
  max_backoff_ms: 50,
  cache_enabled: false
