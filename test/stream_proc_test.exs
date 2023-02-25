defmodule StreamProcTest do
  use ExUnit.Case
  doctest StreamProc

  test "greets the world" do
    assert StreamProc.hello() == :world
  end
end
