defmodule LocalMessageQueueTest do
  use ExUnit.Case
  doctest LocalMessageQueue

  test "greets the world" do
    assert LocalMessageQueue.hello() == :world
  end
end
