defmodule ADSABSClient.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/iamkanishka/adsabs_client.ex"

  def project do
    [
      app: :adsabs_client,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix],
        flags: [:error_handling, :missing_return, :underspecs]
      ],
      # Hex.pm package info
      description:
        "A fully-featured, production-ready Elixir client for the SAO/NASA Astrophysics Data System (ADS) API v1.",
      package: package(),
      # ExDoc
      name: "ADSABSClient",
      source_url: @source_url,
      homepage_url: "https://ui.adsabs.harvard.edu",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ADSABSClient.Application, []}
    ]
  end

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5"},

      # JSON
      {:jason, "~> 1.4"},

      # Config schema validation
      {:nimble_options, "~> 1.1"},

      # Telemetry
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0", optional: true},

      # Dev / Test only
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 0.6", only: [:dev, :test]},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      "test.all": ["test", "dialyzer"],
      lint: ["format --check-formatted", "credo --strict"],
      docs: ["docs", "docs.open"],
      quality: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp package do
    [
      name: "adsabs_client",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "ADS API Docs" => "https://github.com/adsabs/adsabs-dev-api",
        "ADS Portal" => "https://ui.adsabs.harvard.edu"
      },
      maintainers: ["iamkanishka"],
      files: ~w(lib config .formatter.exs mix.exs mix.lock README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Core: [ADSABSClient, ADSABSClient.Application, ADSABSClient.Config],
        HTTP: [ADSABSClient.HTTP, ADSABSClient.HTTP.Behaviour],
        APIs: [
          ADSABSClient.Search,
          ADSABSClient.Export,
          ADSABSClient.Metrics,
          ADSABSClient.Libraries,
          ADSABSClient.Journals,
          ADSABSClient.Resolver,
          ADSABSClient.Objects,
          ADSABSClient.Oracle,
          ADSABSClient.Vis,
          ADSABSClient.Accounts,
          ADSABSClient.CitationHelper,
          ADSABSClient.Feedback
        ],
        "Query Building": [ADSABSClient.Query],
        "Pagination & Concurrency": [ADSABSClient.Pagination, ADSABSClient.Async],
        Types: [
          ADSABSClient.Error,
          ADSABSClient.RateLimitInfo,
          ADSABSClient.Search.Response,
          ADSABSClient.Metrics.Response,
          ADSABSClient.Libraries.Library
        ],
        Telemetry: [ADSABSClient.Telemetry],
        "Rate Limiting": [ADSABSClient.RateLimiter]
      ]
    ]
  end
end
