defmodule ADSABSClient.Integration.AdsWorkflowTest do
  @moduledoc """
  End-to-end integration tests using Bypass to simulate realistic ADS API
  workflows. These tests exercise the full stack — HTTP, retry logic, parsing,
  telemetry, and the RateLimiter — without hitting the real ADS API.
  """

  use ExUnit.Case, async: false

  alias ADSABSClient.{Error, Export, Libraries, Metrics, RateLimiter, Search}
  alias ADSABSClient.Search.Response
  alias Plug.Conn

  @moduletag :integration

  setup do
    bypass = Bypass.open()

    # Ensure we use the real HTTP client, not the Mox mock
    original_client = Application.get_env(:adsabs_client, :http_client)
    Application.put_env(:adsabs_client, :http_client, ADSABSClient.HTTP)
    Application.put_env(:adsabs_client, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:adsabs_client, :api_token, "integration-test-token")
    Application.put_env(:adsabs_client, :max_retries, 2)
    Application.put_env(:adsabs_client, :base_backoff_ms, 5)
    Application.put_env(:adsabs_client, :max_backoff_ms, 20)

    on_exit(fn ->
      Application.put_env(:adsabs_client, :base_url, "http://localhost")

      case original_client do
        nil -> Application.delete_env(:adsabs_client, :http_client)
        val -> Application.put_env(:adsabs_client, :http_client, val)
      end
    end)

    {:ok, bypass: bypass}
  end

  # --- Scenario 1: Search → Export → Metrics pipeline ---

  describe "search → export → metrics workflow" do
    test "fetches papers, exports, and computes metrics", %{bypass: bypass} do
      bibcode = "2016PhRvL.116f1102A"

      # Step 1: Search
      Bypass.expect_once(bypass, "GET", "/search/query", fn conn ->
        assert_auth_header(conn)

        conn
        |> rate_limit_headers(5000, 4999)
        |> json_response(200, %{
          "response" => %{
            "numFound" => 1,
            "start" => 0,
            "docs" => [%{"bibcode" => bibcode, "citation_count" => 8500, "title" => ["GW Paper"]}]
          },
          "nextCursorMark" => "*"
        })
      end)

      {:ok, search_resp} = Search.query("gravitational waves", rows: 1)
      assert %Response{num_found: 1} = search_resp
      assert hd(search_resp.docs)["bibcode"] == bibcode
      assert search_resp.rate_limit.remaining == 4999

      bibcodes = Enum.map(search_resp.docs, & &1["bibcode"])

      # Step 2: Export to BibTeX
      Bypass.expect_once(bypass, "POST", "/export/bibtex", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["bibcode"] == bibcodes

        json_response(conn, 200, %{
          "export" => "@article{#{bibcode}, title={GW Paper}}"
        })
      end)

      {:ok, bibtex} = Export.bibtex(bibcodes)
      assert bibtex =~ "@article"
      assert bibtex =~ bibcode

      # Step 3: Metrics
      Bypass.expect_once(bypass, "POST", "/metrics", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["bibcodes"] == bibcodes

        json_response(conn, 200, %{
          "indicators" => %{"h" => 1, "g" => 1},
          "basic stats" => %{"total citations" => 8500},
          "citation stats" => %{"average number of citations" => 8500.0},
          "histograms" => %{},
          "time series" => %{},
          "skipped bibcodes" => []
        })
      end)

      {:ok, metrics_resp} = Metrics.fetch(bibcodes)
      assert metrics_resp.indicators["h"] == 1
      assert metrics_resp.basic_stats["total citations"] == 8500
    end
  end

  # --- Scenario 2: Retry on 503 then succeed ---

  describe "retry behaviour" do
    test "retries 503 and succeeds on second attempt", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/search/query", fn conn ->
        n = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if n == 0 do
          json_response(conn, 503, %{"error" => "Service Unavailable"})
        else
          conn
          |> rate_limit_headers(5000, 4900)
          |> json_response(200, %{
            "response" => %{"numFound" => 0, "start" => 0, "docs" => []},
            "nextCursorMark" => "*"
          })
        end
      end)

      {:ok, resp} = Search.query("stars")
      assert resp.num_found == 0
      assert :counters.get(call_count, 1) == 2
    end

    test "returns error after exhausting all retries", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/search/query", fn conn ->
        json_response(conn, 500, %{"error" => "Internal Server Error"})
      end)

      {:error, error} = Search.query("stars")
      assert %Error{type: :server_error} = error
    end

    test "handles 429 with retry-after header", %{bypass: bypass} do
      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/search/query", fn conn ->
        n = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        if n == 0 do
          conn
          |> Conn.put_resp_header("retry-after", "1")
          |> json_response(429, %{"error" => "Too Many Requests"})
        else
          conn
          |> rate_limit_headers(5000, 100)
          |> json_response(200, %{
            "response" => %{"numFound" => 5, "start" => 0, "docs" => []},
            "nextCursorMark" => "*"
          })
        end
      end)

      {:ok, resp} = Search.query("black holes")
      assert resp.num_found == 5
    end
  end

  # --- Scenario 3: Cursor pagination ---

  describe "stream/cursor pagination" do
    test "streams across multiple pages", %{bypass: bypass} do
      page1_docs = Enum.map(1..3, fn i -> %{"bibcode" => "code#{i}", "citation_count" => i * 10} end)
      page2_docs = Enum.map(4..5, fn i -> %{"bibcode" => "code#{i}", "citation_count" => i * 10} end)

      call_count = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/search/query", fn conn ->
        n = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        {docs, next_cursor} =
          if n == 0 do
            {page1_docs, "cursor_after_page1"}
          else
            {page2_docs, "cursor_after_page1"}
          end

        conn
        |> rate_limit_headers(5000, 4990 - n)
        |> json_response(200, %{
          "response" => %{"numFound" => 5, "start" => n * 3, "docs" => docs},
          "nextCursorMark" => next_cursor
        })
      end)

      all_docs = "pulsars" |> Search.stream(rows: 3) |> Enum.to_list()

      assert length(all_docs) == 5
      bibcodes = Enum.map(all_docs, & &1["bibcode"])
      assert "code1" in bibcodes
      assert "code5" in bibcodes
    end
  end

  # --- Scenario 4: Error handling ---

  describe "error handling" do
    test "returns :unauthorized for 401" do
      bypass_pid = start_supervised!({Bypass, []})

      Bypass.expect(bypass_pid, "GET", "/search/query", fn conn ->
        json_response(conn, 401, %{"error" => "Unauthorized: missing or invalid token"})
      end)

      # Use a fresh bypass just for this sub-test
      port = bypass_pid.port
      Application.put_env(:adsabs_client, :base_url, "http://localhost:#{port}")

      {:error, error} = Search.query("stars")
      assert error.type == :unauthorized
    end

    test "returns :network_error when server is down", %{bypass: bypass} do
      Bypass.down(bypass)

      {:error, error} = Search.query("stars")
      assert error.type == :network_error

      Bypass.up(bypass)
    end
  end

  # --- Scenario 5: Library CRUD flow ---

  describe "library CRUD workflow" do
    test "create, add docs, list, delete", %{bypass: bypass} do
      # Create
      Bypass.expect_once(bypass, "POST", "/biblib/libraries", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "My Integration Test Library"

        json_response(conn, 200, %{"id" => "new_lib_id", "name" => "My Integration Test Library"})
      end)

      {:ok, lib} = Libraries.create("My Integration Test Library")
      assert lib.id == "new_lib_id"

      # Add documents
      Bypass.expect_once(bypass, "POST", "/biblib/documents/new_lib_id", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["action"] == "add"
        assert length(decoded["bibcode"]) == 1

        json_response(conn, 200, %{"number_added" => 1})
      end)

      {:ok, result} = Libraries.add_documents("new_lib_id", ["2016PhRvL.116f1102A"])
      assert result["number_added"] == 1

      # Delete
      Bypass.expect_once(bypass, "DELETE", "/biblib/libraries/new_lib_id", fn conn ->
        json_response(conn, 200, %{})
      end)

      {:ok, _} = Libraries.delete("new_lib_id")
    end
  end

  # --- Helpers ---

  defp assert_auth_header(conn) do
    auth = conn |> Conn.get_req_header("authorization") |> List.first()
    assert auth == "Bearer integration-test-token"
  end

  defp rate_limit_headers(conn, limit, remaining) do
    reset = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_unix()

    conn
    |> Conn.put_resp_header("x-ratelimit-limit", "#{limit}")
    |> Conn.put_resp_header("x-ratelimit-remaining", "#{remaining}")
    |> Conn.put_resp_header("x-ratelimit-reset", "#{reset}")
  end

  defp json_response(conn, status, body) do
    conn
    |> Conn.put_resp_header("content-type", "application/json")
    |> Conn.send_resp(status, Jason.encode!(body))
  end
end
