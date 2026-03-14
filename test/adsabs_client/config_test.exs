defmodule ADSABSClient.ConfigTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias ADSABSClient.Config

  # Save and restore env around each test
  setup do
    original = Application.get_all_env(:adsabs_client)

    on_exit(fn ->
      # Clear all keys then restore originals
      :adsabs_client
      |> Application.get_all_env()
      |> Enum.each(fn {k, _} -> Application.delete_env(:adsabs_client, k) end)

      Enum.each(original, fn {k, v} ->
        Application.put_env(:adsabs_client, k, v)
      end)
    end)

    :ok
  end

  describe "validate!/0" do
    test "succeeds with valid config" do
      Application.put_env(:adsabs_client, :api_token, "valid-token")
      assert is_list(Config.validate!())
    end

    test "succeeds with nil token (allowed — token may be set later)" do
      Application.put_env(:adsabs_client, :api_token, nil)
      assert is_list(Config.validate!())
    end

    test "raises on invalid type for timeout" do
      Application.put_env(:adsabs_client, :receive_timeout, "not_an_integer")

      assert_raise RuntimeError, ~r/Invalid ADSABSClient configuration/, fn ->
        Config.validate!()
      end
    end

    test "raises on negative integer where pos_integer expected" do
      Application.put_env(:adsabs_client, :connect_timeout, -1)

      assert_raise RuntimeError, ~r/Invalid ADSABSClient configuration/, fn ->
        Config.validate!()
      end
    end
  end

  describe "get/2" do
    test "returns configured value" do
      Application.put_env(:adsabs_client, :max_retries, 5)
      assert Config.get(:max_retries) == 5
    end

    test "returns default when key not set" do
      Application.delete_env(:adsabs_client, :nonexistent_key)
      assert Config.get(:nonexistent_key, :my_default) == :my_default
    end

    test "returns nil default when no default given" do
      Application.delete_env(:adsabs_client, :nonexistent_key)
      assert Config.get(:nonexistent_key) == nil
    end
  end

  describe "api_token!/0" do
    test "returns token when configured" do
      Application.put_env(:adsabs_client, :api_token, "my-secret-token")
      assert Config.api_token!() == "my-secret-token"
    end

    test "raises when token is nil" do
      Application.put_env(:adsabs_client, :api_token, nil)

      assert_raise RuntimeError, ~r/api_token is not configured/, fn ->
        Config.api_token!()
      end
    end

    test "raises when token key is absent" do
      Application.delete_env(:adsabs_client, :api_token)

      assert_raise RuntimeError, ~r/api_token is not configured/, fn ->
        Config.api_token!()
      end
    end
  end

  describe "schema/0" do
    test "returns a NimbleOptions schema" do
      schema = Config.schema()
      assert %NimbleOptions{} = schema
    end
  end
end
