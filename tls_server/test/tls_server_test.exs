defmodule TLS_SERVERTest do
  use ExUnit.Case
  doctest TLS_SERVER

  test "greets the world" do
    assert TLS_SERVER.hello() == :world
  end
end
