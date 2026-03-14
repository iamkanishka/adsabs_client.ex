# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] — 2026-03-13

### Added
- **Complete API coverage**: Export, Metrics, Libraries, Journals, Resolver, Objects, Oracle, Vis, Accounts
- `ADSABSClient.Query` — composable Solr query builder DSL
- `ADSABSClient.Search.stream/2` — lazy cursor-based pagination via Elixir Stream
- `ADSABSClient.Search.bigquery/2` — large bibcode set search
- `ADSABSClient.Search.citations/2`, `references/2`, `trending/2`
- Structured error type `ADSABSClient.Error` with typed `:type` field
- `ADSABSClient.RateLimitInfo` — parsed from `X-RateLimit-*` headers on every response
- `ADSABSClient.Search.Response` — typed struct for search results (replaces raw maps)
- `ADSABSClient.Metrics.Response` — typed struct for metrics results
- `ADSABSClient.Libraries.Library` — typed struct for library metadata
- Automatic retry with exponential backoff + jitter on 429 and 5xx responses
- Full Telemetry integration (`[:adsabs_client, :request, :*]`, `[:adsabs_client, :rate_limit, :*]`)
- NimbleOptions config schema validation at application startup
- `ADSABSClient.HTTP.Behaviour` — allows Mox testing without Bypass
- GitHub Actions CI pipeline: lint, test matrix (Elixir 1.15/1.16/1.17), Dialyzer, security audit, Hex publish
- Full test suite: unit tests, Bypass integration tests, StreamData property tests
- Strict `.credo.exs` configuration
- Dialyzer with PLT caching
- CHANGELOG, LICENSE, comprehensive README

### Fixed
- README was the default `mix new` placeholder — replaced with full documentation
- No structured error types — all errors now return `%ADSABSClient.Error{}`
- No rate limit handling — 429 now retried with backoff
- No retry logic — 5xx now retried up to `max_retries` times
- Config had no validation — NimbleOptions schema added
- No `@spec`, `@doc`, or `@moduledoc` — all public functions now fully documented

### Changed
- Migrated from HTTPoison to Req (maintained by the Elixir community, better API)
- Config keys now validated against NimbleOptions schema on startup

## [0.1.0] — Initial commit

### Added
- Initial project scaffold with `mix new`
- Basic HTTP scaffolding for Search API
