defmodule LocalMessageQueue.ConsumerTest do
  use ExUnit.Case, async: true

  @registry __MODULE__.Registry
  @id __MODULE__
  @publisher_key __MODULE__.Doubled

  setup do
    start_supervised!({Registry, keys: :unique, name: @registry})

    queue_name = {:via, Registry, {@registry, System.unique_integer([:monotonic])}}

    queue_config = %{
      id: @id,
      name: queue_name,
      filter: nil,
      registry: @registry
    }

    start_supervised!({LocalMessageQueue.Queue, queue_config})

    name = {:via, Registry, {@registry, System.unique_integer([:monotonic])}}

    config = %{
      id: @id,
      name: name,
      registry: @registry,
      producer: LocalMessageQueue.Producers.Double,
      publisher_key: @publisher_key,
      queue_name: queue_name,
      delay: nil,
      cache: nil
    }

    start_supervised!({LocalMessageQueue.Consumer, config})

    %{queue_name: queue_name}
  end

  test "consumes message from queue and dispatches it to listeners", %{queue_name: queue_name} do
    # register as a listener
    :ok = LocalMessageQueue.listen(@registry, @publisher_key)

    # the consumer should double this value per the producer configuration
    input = 4

    LocalMessageQueue.Queue.concat(queue_name, [input])

    assert_receive({:new_msgs, @publisher_key, [8]})
  end
end
