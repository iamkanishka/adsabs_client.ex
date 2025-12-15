defmodule AdsClient.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/your_org/ads_client"

  def project do
    [
      app: :ads_client,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: dialyzer(),
      preferred_cli_env: [
        "test.integration": :test
      ],
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AdsClient.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.4.0"},

      # JSON parsing
      {:jason, "~> 1.4"},

      # SSL certificates
      {:castore, "~> 1.0"},

      # Telemetry
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 0.6", optional: true},
      {:telemetry_poller, "~> 1.0", optional: true},

      # Testing
      {:mox, "~> 1.0", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:stream_data, "~> 0.6", only: :test},

      # Development
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Elixir client for NASA Astrophysics Data System (ADS) API with support for
    search, metrics, export, libraries, and 80+ API operations. Includes
    streaming, pagination, retry logic, and comprehensive error handling.
    """
  end

  defp package do
    [
      name: "ads_client",
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "ADS API Docs" => "https://ui.adsabs.harvard.edu/help/api",
        "ADS OpenAPI" => "https://ui.adsabs.harvard.edu/help/api/api-docs.html"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "AdsClient",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Core API": [
          AdsClient,
          AdsClient.Search,
          AdsClient.Metrics,
          AdsClient.Export,
          AdsClient.Libraries,
          AdsClient.Resolver
        ],
        "Behaviours": [
          AdsClient.Adapter
        ],
        "Adapters": [
          AdsClient.Adapter.Req
        ],
        "Types & Structs": [
          AdsClient.SearchResult,
          AdsClient.Metrics.Result,
          AdsClient.Library,
          AdsClient.Error
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [:unmatched_returns, :error_handling, :underspecs]
    ]
  end

  defp aliases do
    [
      "test.integration": ["test --only integration"],
      "test.all": ["test --include integration"]
    ]
  end
end
