# ADSABSClient

[![CI](https://github.com/iamkanishka/adsabs_client.ex/actions/workflows/ci.yml/badge.svg)](https://github.com/iamkanishka/adsabs_client.ex/actions)
[![Hex.pm](https://img.shields.io/hexpm/v/adsabs_client.svg)](https://hex.pm/packages/adsabs_client)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/adsabs_client)
[![Coverage](https://codecov.io/gh/iamkanishka/adsabs_client.ex/branch/master/graph/badge.svg)](https://codecov.io/gh/iamkanishka/adsabs_client.ex)
[![License](https://img.shields.io/hexpm/l/adsabs_client.svg)](LICENSE)

A fully-featured, production-ready **Elixir client** for the
[SAO/NASA Astrophysics Data System (ADS) API v1](https://github.com/adsabs/adsabs-dev-api).

## Features

- ✅ **Complete API coverage** — Search, Export, Metrics, Libraries, Journals, Resolver, Objects, Oracle, Visualizations
- 🔄 **Automatic retry** with exponential backoff + jitter on 5xx and 429 responses
- 📊 **Rate-limit awareness** — parses `X-RateLimit-*` headers and emits Telemetry warnings
- 📡 **Telemetry integration** — `:telemetry.span` events for Prometheus / Grafana / AppSignal
- 🔍 **Composable Query DSL** — type-safe Solr query builder, no raw string construction needed
- 🌊 **Lazy Stream pagination** — cursor-based pagination via Elixir `Stream`, works for any result set size
- 🧪 **Testable by design** — HTTP behaviour + Mox support, no global state
- ⚙️ **Config validation** — NimbleOptions schema catches misconfiguration at startup
- 📖 **Fully documented** — `@doc`, `@spec`, `@moduledoc` on every public function

## Installation

```elixir
def deps do
  [
    {:adsabs_client, "~> 0.2"}
  ]
end
```

## Configuration

```elixir
# config/config.exs
config :adsabs_client,
  api_token: System.get_env("ADS_API_TOKEN"),
  # Optional overrides (all have sensible defaults):
  base_url: "https://api.adsabs.harvard.edu/v1",
  receive_timeout: 30_000,       # ms
  connect_timeout: 5_000,        # ms
  max_retries: 3,
  base_backoff_ms: 500,
  max_backoff_ms: 30_000,
  rate_limit_warning_threshold: 100
```

Get your API token at: https://ui.adsabs.harvard.edu/user/settings/token

## Quick Start

```elixir
# Simple string search
{:ok, resp} = ADSABSClient.Search.query("black holes", rows: 10)
resp.num_found          # => 15_432
resp.docs               # => [%{"bibcode" => "...", "title" => [...], ...}, ...]
resp.rate_limit.remaining  # => 4980

# Using the Query builder DSL
alias ADSABSClient.Query

{:ok, resp} =
  Query.new()
  |> Query.author("Hawking, S")
  |> Query.year_range(1970, 2018)
  |> Query.property(:refereed)
  |> Query.fields(["title", "bibcode", "citation_count", "year"])
  |> Query.sort("citation_count", :desc)
  |> Query.rows(20)
  |> ADSABSClient.Search.query()

# Export references to BibTeX
bibcodes = Enum.map(resp.docs, & &1["bibcode"])
{:ok, bibtex} = ADSABSClient.Export.bibtex(bibcodes)

# Metrics
{:ok, metrics} = ADSABSClient.Metrics.fetch(bibcodes)
metrics.indicators["h"]   # h-index
metrics.indicators["g"]   # g-index

# Stream-based lazy pagination (fetches pages on demand)
ADSABSClient.Search.stream("gravitational waves property:refereed")
|> Stream.filter(&((&1["citation_count"] || 0) > 100))
|> Enum.take(500)
```

## API Reference

### Search

```elixir
# String query
{:ok, resp} = ADSABSClient.Search.query("author:Einstein year:1905")

# Find papers citing a bibcode
{:ok, resp} = ADSABSClient.Search.citations(["2016PhRvL.116f1102A"])

# Find references within a paper
{:ok, resp} = ADSABSClient.Search.references(["2016PhRvL.116f1102A"])

# Trending papers related to a query
{:ok, resp} = ADSABSClient.Search.trending("neutron stars")

# Large bibcode set search
{:ok, resp} = ADSABSClient.Search.bigquery(my_bibcode_list, fields: ["title"])

# Infinite lazy stream
stream = ADSABSClient.Search.stream("stellar evolution", rows: 200)
```

### Export

```elixir
bibcodes = ["2016PhRvL.116f1102A"]

{:ok, bibtex}  = ADSABSClient.Export.bibtex(bibcodes)
{:ok, ris}     = ADSABSClient.Export.ris(bibcodes)
{:ok, endnote} = ADSABSClient.Export.endnote(bibcodes)
{:ok, aastex}  = ADSABSClient.Export.aastex(bibcodes)
{:ok, mnras}   = ADSABSClient.Export.mnras(bibcodes)

# Custom template
{:ok, custom} = ADSABSClient.Export.custom(bibcodes, "%T\n%A\n%Y\n")
```

### Metrics

```elixir
{:ok, m} = ADSABSClient.Metrics.fetch(bibcodes)
m.indicators["h"]                          # h-index
m.basic_stats["total citations"]           # total citation count
m.citation_stats["average number of citations"]

# Scoped requests
{:ok, _} = ADSABSClient.Metrics.indicators(bibcodes)
{:ok, _} = ADSABSClient.Metrics.citations(bibcodes)
{:ok, _} = ADSABSClient.Metrics.timeseries(bibcodes)
```

### Libraries

```elixir
{:ok, libs}   = ADSABSClient.Libraries.list()
{:ok, lib}    = ADSABSClient.Libraries.create("My Reading List", description: "Important papers")
{:ok, lib}    = ADSABSClient.Libraries.get(lib.id)
{:ok, _}      = ADSABSClient.Libraries.add_documents(lib.id, bibcodes)
{:ok, _}      = ADSABSClient.Libraries.remove_documents(lib.id, ["old_bibcode"])
{:ok, _}      = ADSABSClient.Libraries.delete(lib.id)

# Permissions
{:ok, _} = ADSABSClient.Libraries.set_permission(lib.id,
  email: "colleague@example.com",
  permission: "read"
)

# Set operations
{:ok, _} = ADSABSClient.Libraries.operation(lib_a_id,
  operation: "union",
  libraries: [lib_b_id],
  name: "Combined Library"
)
```

### Journals

```elixir
{:ok, summary}  = ADSABSClient.Journals.summary("ApJ")
{:ok, journal}  = ADSABSClient.Journals.journal("A&A")
{:ok, vol}      = ADSABSClient.Journals.volume("ApJ", "900")
{:ok, journal}  = ADSABSClient.Journals.by_issn("0004-637X")
{:ok, holdings} = ADSABSClient.Journals.holdings("Icar")
```

### Resolver

```elixir
{:ok, links}  = ADSABSClient.Resolver.resolve("2016PhRvL.116f1102A")
{:ok, result} = ADSABSClient.Resolver.resolve("2016PhRvL.116f1102A", :full)
{:ok, url}    = ADSABSClient.Resolver.full_text_url("2016PhRvL.116f1102A")
{:ok, url}    = ADSABSClient.Resolver.preprint_url("2016PhRvL.116f1102A")
```

### Oracle (Recommendations)

```elixir
{:ok, recs} = ADSABSClient.Oracle.also_read(["2016PhRvL.116f1102A"])

{:ok, matches} = ADSABSClient.Oracle.match_document(
  title: "Observation of Gravitational Waves",
  abstract: "We report the direct detection of gravitational waves...",
  author: ["Abbott, B.P."]
)
```

## Error Handling

All functions return `{:ok, result}` or `{:error, %ADSABSClient.Error{}}`:

```elixir
case ADSABSClient.Search.query("stars") do
  {:ok, resp} ->
    process(resp.docs)

  {:error, %ADSABSClient.Error{type: :rate_limited, retry_after: secs}} ->
    Logger.warning("Rate limited — retry after #{secs}s")
    :timer.sleep(secs * 1_000)
    # retry...

  {:error, %ADSABSClient.Error{type: :unauthorized}} ->
    raise "Invalid API token — check ADS_API_TOKEN env var"

  {:error, %ADSABSClient.Error{type: :network_error, message: msg}} ->
    Logger.error("Network failure: #{msg}")

  {:error, error} ->
    Logger.error("ADS API error [#{error.type}]: #{error.message}")
end
```

Error types: `:unauthorized`, `:forbidden`, `:not_found`, `:rate_limited`,
`:server_error`, `:network_error`, `:decode_error`, `:validation_error`

## Telemetry

Attach to telemetry events for observability:

```elixir
# Attach the built-in logger handler
:telemetry.attach_many(
  "adsabs-logger",
  [
    [:adsabs_client, :request, :stop],
    [:adsabs_client, :rate_limit, :warning],
    [:adsabs_client, :rate_limit, :exceeded]
  ],
  &ADSABSClient.Telemetry.log_handler/4,
  nil
)
```

Events emitted:
- `[:adsabs_client, :request, :start]`
- `[:adsabs_client, :request, :stop]` — includes duration, status, rate_limit
- `[:adsabs_client, :request, :exception]`
- `[:adsabs_client, :rate_limit, :warning]` — when remaining < threshold
- `[:adsabs_client, :rate_limit, :exceeded]` — on 429
- `[:adsabs_client, :retry, :attempt]` — on each retry

## Testing

```elixir
# In test_helper.exs
Mox.defmock(ADSABSClient.HTTP.Mock, for: ADSABSClient.HTTP.Behaviour)
Application.put_env(:adsabs_client, :http_client, ADSABSClient.HTTP.Mock)

# In your test
import Mox

expect(ADSABSClient.HTTP.Mock, :get, fn "/search/query", _opts ->
  {:ok, %{status: 200, headers: [], body: %{"response" => %{"numFound" => 1, "docs" => []}}}}
end)

{:ok, resp} = ADSABSClient.Search.query("stars")
assert resp.num_found == 1
```

## License

Apache 2.0 — see [LICENSE](LICENSE).
