defmodule AdsClientTest do
  use ExUnit.Case
  doctest AdsClient

  test "greets the world" do
    assert AdsClient.hello() == :world
  end
end
