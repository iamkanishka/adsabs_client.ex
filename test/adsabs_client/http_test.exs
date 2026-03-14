defmodule ADSABSClient.HTTPTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias ADSABSClient.{Error, HTTP}
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    Application.put_env(:adsabs_client, :base_url, "http://localhost:#{bypass.port}")
    Application.put_env(:adsabs_client, :api_token, "test-token")
    Application.put_env(:adsabs_client, :max_retries, 1)
    Application.put_env(:adsabs_client, :base_backoff_ms, 10)
    Application.put_env(:adsabs_client, :max_backoff_ms, 50)

    on_exit(fn ->
      Application.put_env(:adsabs_client, :base_url, "http://localhost")
    end)

    {:ok, bypass: bypass}
  end

  describe "get/2" do
    test "sends Authorization header with Bearer token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/search/query", fn conn ->
        auth = conn |> Conn.get_req_header("authorization") |> List.first()
        assert auth == "Bearer test-token"
        json_response(conn, 200, %{"response" => %{"docs" => []}})
      end)

      {:ok, resp} = HTTP.get("/search/query", params: %{"q" => "stars"})
      assert resp.status == 200
    end

    test "sends User-Agent header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/search/query", fn conn ->
        ua = conn |> Conn.get_req_header("user-agent") |> List.first()
        assert ua =~ "adsabs_client"
        json_response(conn, 200, %{})
      end)

      HTTP.get("/search/query")
    end

    test "returns ok with parsed JSON body", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/search/query", fn conn ->
        json_response(conn, 200, %{"response" => %{"numFound" => 42, "docs" => []}})
      end)

      {:ok, resp} = HTTP.get("/search/query")
      assert resp.status == 200
      assert resp.body["response"]["numFound"] == 42
    end

    test "returns error struct for 401", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/search/query", fn conn ->
        json_response(conn, 401, %{"error" => "Unauthorized"})
      end)

      {:error, error} = HTTP.get("/search/query")
      assert %Error{type: :unauthorized} = error
    end

    test "returns error struct for 404", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/missing", fn conn ->
        json_response(conn, 404, %{"error" => "Not found"})
      end)

      {:error, error} = HTTP.get("/missing")
      assert %Error{type: :not_found} = error
    end

    test "retries on 500 then succeeds", %{bypass: bypass} do
      attempt = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/search/query", fn conn ->
        count = :counters.get(attempt, 1)
        :counters.add(attempt, 1, 1)

        if count == 0 do
          json_response(conn, 500, %{"error" => "Internal Server Error"})
        else
          json_response(conn, 200, %{"response" => %{"docs" => []}})
        end
      end)

      {:ok, resp} = HTTP.get("/search/query")
      assert resp.status == 200
      assert :counters.get(attempt, 1) == 2
    end

    test "returns error after max_retries exhausted on 500", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/search/query", fn conn ->
        json_response(conn, 500, %{"error" => "Server Error"})
      end)

      {:error, error} = HTTP.get("/search/query")
      assert %Error{type: :server_error} = error
    end

    test "parses rate limit headers", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/search/query", fn conn ->
        conn
        |> Conn.put_resp_header("x-ratelimit-limit", "5000")
        |> Conn.put_resp_header("x-ratelimit-remaining", "4500")
        |> Conn.put_resp_header("x-ratelimit-reset", "1735689600")
        |> json_response(200, %{})
      end)

      {:ok, resp} = HTTP.get("/search/query")
      assert resp.status == 200

      remaining =
        Enum.find_value(resp.headers, fn
          {"x-ratelimit-remaining", v} -> v
          _ -> nil
        end)

      assert remaining == "4500"
    end

    test "handles network error gracefully when server is down", %{bypass: bypass} do
      Bypass.down(bypass)

      {:error, error} = HTTP.get("/search/query")
      assert %Error{type: :network_error} = error
    end
  end

  describe "post/3" do
    test "sends JSON body", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/metrics", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["bibcodes"] == ["2016PhRvL.116f1102A"]
        json_response(conn, 200, %{"indicators" => %{"h" => 5}})
      end)

      {:ok, resp} = HTTP.post("/metrics", %{"bibcodes" => ["2016PhRvL.116f1102A"]})
      assert resp.status == 200
    end

    test "sends Content-Type: application/json", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/export/bibtex", fn conn ->
        ct = conn |> Conn.get_req_header("content-type") |> List.first()
        assert ct =~ "application/json"
        json_response(conn, 200, %{"export" => "@article{...}"})
      end)

      HTTP.post("/export/bibtex", %{"bibcode" => ["abc"]})
    end

    test "sends plain-text body with custom Content-Type when body is a string", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/search/bigquery", fn conn ->
        ct = conn |> Conn.get_req_header("content-type") |> List.first()
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert ct =~ "big-query/csv"
        assert String.starts_with?(body, "bibcode\n")
        json_response(conn, 200, %{"response" => %{"numFound" => 1, "docs" => []}})
      end)

      HTTP.post("/search/bigquery", "bibcode\n2016PhRvL.116f1102A", content_type: "big-query/csv")
    end
  end

  describe "delete/2" do
    test "sends DELETE request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/biblib/libraries/abc123", fn conn ->
        json_response(conn, 200, %{})
      end)

      {:ok, resp} = HTTP.delete("/biblib/libraries/abc123")
      assert resp.status == 200
    end
  end

  # --- Helpers ---

  defp json_response(conn, status, body) do
    conn
    |> Conn.put_resp_header("content-type", "application/json")
    |> Conn.send_resp(status, Jason.encode!(body))
  end
end
