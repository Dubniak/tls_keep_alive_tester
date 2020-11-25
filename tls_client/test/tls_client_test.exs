defmodule TLS_CLIENTTest do
  use ExUnit.Case
  doctest TLS_CLIENT

  test "greets the world" do
    assert TLS_CLIENT.hello() == :world
  end
end
