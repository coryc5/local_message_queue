defmodule LocalMessageQueue.PreloaderTest do
  use ExUnit.Case, async: true

  alias LocalMessageQueue.Cache

  @registry __MODULE__.Registry
  @id __MODULE__
  @subscription_key __MODULE__.NewNumber
  @publisher_key __MODULE__.Doubled

  setup context do
    start_supervised!({Registry, keys: :unique, name: @registry})

    cache_name =
      case context[:cache] do
        true ->
          cache_name = {:via, Registry, {@registry, System.unique_integer([:monotonic])}}
          expiration_ms = 200

          start_supervised!({Cache, {cache_name, expiration_ms}})

          cache_name

        false ->
          nil
      end

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
      name: name,
      registry: @registry,
      subscription_key: @subscription_key,
      publisher_key: @publisher_key,
      cache: cache_name,
      queue: queue_name
    }

    start_supervised!({LocalMessageQueue.Preloader, config})

    %{queue_name: queue_name, cache_name: cache_name}
  end

  @tag cache: false
  test "adds all messages to queue when cache not configured", %{queue_name: queue_name} do
    # register as a listener to queue
    :ok = LocalMessageQueue.listen_to_queue(@registry, @id)

    # register as listener to publisher_key
    :ok = LocalMessageQueue.listen(@registry, @publisher_key)

    input = [1, 2, 3]

    LocalMessageQueue.dispatch_new_msgs(@registry, @subscription_key, input)

    assert_receive({:queue_add, ^queue_name})
    assert LocalMessageQueue.Queue.len(queue_name) == length(input)

    # preload dispatched no messages
    refute_receive({:new_msgs, @publisher_key, _})
  end

  @tag cache: true
  test "dispatches results of messages that have been cached and does not add them to the queue",
       %{queue_name: queue_name, cache_name: cache_name} do
    first_msg = 1
    cached_result = [first_msg * 2]
    Cache.put(cache_name, first_msg, cached_result)

    # register as a listener to queue
    :ok = LocalMessageQueue.listen_to_queue(@registry, @id)

    # register as listener to publisher_key
    :ok = LocalMessageQueue.listen(@registry, @publisher_key)

    input = [first_msg, 2, 3]

    LocalMessageQueue.dispatch_new_msgs(@registry, @subscription_key, input)

    assert_receive({:queue_add, ^queue_name})
    assert LocalMessageQueue.Queue.len(queue_name) == length(input) - 1

    # preloader dispatched cached results
    assert_receive({:new_msgs, @publisher_key, cached_result})
  end
end
