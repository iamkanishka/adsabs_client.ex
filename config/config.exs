import Config

config :adsabs_client,
  # Required: Your ADS API token — https://ui.adsabs.harvard.edu/user/settings/token
  api_token: System.get_env("ADS_API_TOKEN"),

  # Base URL for the ADS API (override for mirrors or staging)
  base_url: "https://api.adsabs.harvard.edu/v1",

  # HTTP request timeouts in milliseconds
  connect_timeout: 5_000,
  receive_timeout: 30_000,

  # Retry configuration
  max_retries: 3,
  base_backoff_ms: 500,
  max_backoff_ms: 30_000,

  # Rate limit warning threshold (warn when remaining < this value)
  rate_limit_warning_threshold: 100,

  # Optional caching (requires :cachex in deps if enabled)
  cache_enabled: false,
  cache_ttl_seconds: 300,

  # Pool size for concurrent requests
  pool_size: 10

import_config "#{config_env()}.exs"
