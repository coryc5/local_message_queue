defmodule LocalMessageQueue.QueueTest do
  use ExUnit.Case, async: true

  alias LocalMessageQueue.{TestHelpers, Queue}

  setup context do
    registry = __MODULE__.Registry
    start_supervised!({Registry, keys: :unique, name: registry})

    name = {:via, Registry, {registry, System.unique_integer([:monotonic])}}

    config = %{
      id: __MODULE__,
      name: name,
      filter: context[:filter],
      registry: registry
    }

    start_supervised!({Queue, config})

    %{name: name}
  end

  describe "adding and removing items from the queue" do
    test "concat adds a list of items to the end of the queue", %{name: name} do
      input = [1, 2, 3]

      _result = Queue.concat(name, input)

      assert Queue.len(name) == length(input)

      Enum.each(input, fn item ->
        assert Queue.pop(name) == item
      end)

      assert Queue.len(name) == 0
    end

    test "all added items end up in the queue", %{name: name} do
      input = [1, 2, 3]

      # these items first get added to the `pre_stack_queue`
      _result = Queue.concat(name, input)

      # this will move the items from the `pre_stack_queue` to the `queue` since the queue is empty
      assert Queue.pop(name) == hd(input)

      more_input = [4, 5]
      _result = Queue.concat(name, more_input)

      assert Queue.len(name) == 4

      Enum.each(tl(input) ++ more_input, fn item ->
        assert Queue.pop(name) == item
      end)

      assert Queue.len(name) == 0
    end

    test "pop returns :empty if queue is empty", %{name: name} do
      assert Queue.pop(name) == :empty
    end

    @tag filter: &TestHelpers.greater_than_one?/1
    test "concat filters out items via a filter fun", %{name: name} do
      input = [1, 2, 3]

      _result = Queue.concat(name, input)

      assert Queue.len(name) == length(input) - 1

      Enum.each(tl(input), fn item ->
        assert Queue.pop(name) == item
      end)

      assert Queue.len(name) == 0
    end
  end
end
