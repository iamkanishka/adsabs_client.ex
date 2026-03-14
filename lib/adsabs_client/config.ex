defmodule ADSABSClient.Config do
  @moduledoc """
  Configuration validation and access for ADSABSClient.

  All config is read from `Application.get_env/3` under the `:adsabs_client` key.
  Use `ADSABSClient.Config.validate!/0` at startup to catch misconfigurations early.

  ## Configuration Keys

  | Key | Type | Default | Description |
  |---|---|---|---|
  | `:api_token` | `string` | **required** | ADS API Bearer token |
  | `:base_url` | `string` | `"https://api.adsabs.harvard.edu/v1"` | API base URL |
  | `:connect_timeout` | `pos_integer` | `5_000` | TCP connect timeout (ms) |
  | `:receive_timeout` | `pos_integer` | `30_000` | HTTP read timeout (ms) |
  | `:max_retries` | `non_neg_integer` | `3` | Max retry attempts on 5xx/429 |
  | `:base_backoff_ms` | `pos_integer` | `500` | Initial backoff delay (ms) |
  | `:max_backoff_ms` | `pos_integer` | `30_000` | Max backoff delay (ms) |
  | `:rate_limit_warning_threshold` | `pos_integer` | `100` | Telemetry warning threshold |
  | `:cache_enabled` | `boolean` | `false` | Enable response caching |
  | `:cache_ttl_seconds` | `pos_integer` | `300` | Cache TTL in seconds |
  | `:pool_size` | `pos_integer` | `10` | HTTP connection pool size |
  """

  @schema NimbleOptions.new!(
            api_token: [
              type: {:or, [:string, nil]},
              default: nil,
              doc: "ADS API Bearer token. Get yours at https://ui.adsabs.harvard.edu/user/settings/token"
            ],
            base_url: [
              type: :string,
              default: "https://api.adsabs.harvard.edu/v1",
              doc: "ADS API base URL"
            ],
            connect_timeout: [
              type: :pos_integer,
              default: 5_000,
              doc: "TCP connect timeout in milliseconds"
            ],
            receive_timeout: [
              type: :pos_integer,
              default: 30_000,
              doc: "HTTP receive timeout in milliseconds"
            ],
            max_retries: [
              type: :non_neg_integer,
              default: 3,
              doc: "Maximum retry attempts on retryable errors"
            ],
            base_backoff_ms: [
              type: :pos_integer,
              default: 500,
              doc: "Initial backoff delay in milliseconds"
            ],
            max_backoff_ms: [
              type: :pos_integer,
              default: 30_000,
              doc: "Maximum backoff delay in milliseconds"
            ],
            rate_limit_warning_threshold: [
              type: :pos_integer,
              default: 100,
              doc: "Emit a telemetry warning when X-RateLimit-Remaining drops below this"
            ],
            cache_enabled: [
              type: :boolean,
              default: false,
              doc: "Enable in-process response caching (requires :cachex)"
            ],
            cache_ttl_seconds: [
              type: :pos_integer,
              default: 300,
              doc: "Cache TTL in seconds"
            ],
            pool_size: [
              type: :pos_integer,
              default: 10,
              doc: "HTTP connection pool size"
            ]
          )

  @doc "Validate all config at startup. Raises if config is invalid."
  @spec validate!() :: keyword() | map()
  @spec validate!() :: keyword()
  def validate! do
    schema_keys = @schema.schema |> Keyword.keys()
    raw = :adsabs_client |> Application.get_all_env() |> Keyword.take(schema_keys)

    case NimbleOptions.validate(raw, @schema) do
      {:ok, validated} ->
        validated

      {:error, %NimbleOptions.ValidationError{message: msg}} ->
        raise """
        Invalid ADSABSClient configuration: #{msg}

        Please check your config/config.exs. Required: `api_token`.
        See ADSABSClient.Config documentation for all options.
        """
    end
  end

  @doc "Fetch a single config value with a default fallback."
  @spec get(atom(), term()) :: term()
  def get(key, default \\ nil) do
    Application.get_env(:adsabs_client, key, default)
  end

  @doc "Fetch the API token. Raises if not set."
  @spec api_token!() :: String.t()
  def api_token! do
    case get(:api_token) do
      nil ->
        raise """
        ADSABSClient: api_token is not configured.

        Set it in config/config.exs:
            config :adsabs_client, api_token: System.get_env("ADS_API_TOKEN")

        Or set the ADS_API_TOKEN environment variable.
        """

      token ->
        token
    end
  end

  @doc "Returns the full NimbleOptions schema for introspection."
  @spec schema() :: NimbleOptions.t()
  def schema, do: @schema
end
