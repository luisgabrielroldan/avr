defmodule AVRTest do
  use ExUnit.Case
  doctest Avr

  test "greets the world" do
    assert Avr.hello() == :world
  end
end
