defmodule ADSABSClient.MetricsTest do
  @moduledoc false
  use ADSABSClient.Test.MockCase, async: true

  alias ADSABSClient.{Error, Metrics}
  alias ADSABSClient.Metrics.Response
  alias ADSABSClient.Test.Fixtures

  @bibcodes ["2016PhRvL.116f1102A", "2019ApJ...882L..24A"]

  describe "fetch/2" do
    test "returns a Response struct" do
      body = Fixtures.metrics_response_body()

      expect(ADSABSClient.HTTP.Mock, :post, fn "/metrics", _body, _opts ->
        Fixtures.ok_response(body)
      end)

      {:ok, resp} = Metrics.fetch(@bibcodes)
      assert %Response{} = resp
    end

    test "parses indicators correctly" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/metrics", _body, _opts ->
        Fixtures.ok_response(Fixtures.metrics_response_body())
      end)

      {:ok, resp} = Metrics.fetch(@bibcodes)

      assert resp.indicators["h"] == 3
      assert resp.indicators["g"] == 3
      assert resp.indicators["i10"] == 3
    end

    test "parses basic stats" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/metrics", _body, _opts ->
        Fixtures.ok_response(Fixtures.metrics_response_body())
      end)

      {:ok, resp} = Metrics.fetch(@bibcodes)

      assert resp.basic_stats["number of papers"] == 3
      assert resp.basic_stats["total citations"] == 13_800
    end

    test "returns validation error for empty bibcodes" do
      {:error, error} = Metrics.fetch([])
      assert error.type == :validation_error
    end
  end

  describe "citations/2" do
    test "sends types=[citations] in request body" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/metrics", body, _opts ->
        assert body["types"] == ["citations"]
        Fixtures.ok_response(Fixtures.metrics_response_body())
      end)

      {:ok, _} = Metrics.citations(@bibcodes)
    end
  end

  describe "indicators/2" do
    test "sends types=[indicators] in request body" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/metrics", body, _opts ->
        assert body["types"] == ["indicators"]
        Fixtures.ok_response(Fixtures.metrics_response_body())
      end)

      {:ok, _} = Metrics.indicators(@bibcodes)
    end
  end

  describe "basic/2" do
    test "sends types=[basic] in request body" do
      expect(ADSABSClient.HTTP.Mock, :post, fn "/metrics", body, _opts ->
        assert body["types"] == ["basic"]
        Fixtures.ok_response(Fixtures.metrics_response_body())
      end)

      {:ok, _} = Metrics.basic(@bibcodes)
    end
  end

  describe "Metrics.Response.from_response/1" do
    test "handles missing keys gracefully" do
      resp = Response.from_response(%{})

      assert resp.basic_stats == %{}
      assert resp.indicators == %{}
      assert resp.skipped_bibcodes == []
    end

    test "parses skipped bibcodes" do
      body = Map.put(Fixtures.metrics_response_body(), "skipped bibcodes", ["bad_code"])
      resp = Response.from_response(body)

      assert resp.skipped_bibcodes == ["bad_code"]
    end
  end
end
