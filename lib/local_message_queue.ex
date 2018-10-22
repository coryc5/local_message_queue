defmodule LocalMessageQueue do
  @moduledoc """
  A local message queue for cacheable, asynchronous processing.

  It allows developers to set up an asynchronous pipeline that is easily observable. Message queues
  are groups of processes that use the `Registry` module to implement pub/sub behavior. Other
  processes can subscribe to topics published by these queues to receive messages and check in on
  queue sizes.

  ## Processing flow

  A LocalMessageQueue consists of several processes: `Preloader`, `Cache`, `Queue`, `Consumer`.
  These four processes exist in their own supervision tree. The `Preloader` uses the `Registry`
  to subscribe to messages. Upon receiving those messages, it will check if a `Cache` has been
  enabled for this particular queue and if so, split out messages that exist unexpired in the cache
  and immediately publish them. Messages that have not been cached are then added to the `Queue`.
  The `Queue` will publish that it has had messages added to it, which will trigger the `Consumer`
  to begin pulling messages from it. These messages are processed by a configured `Producer`
  callback, and the results are added to the cache if it has been enabled. Finally, these results
  are then published under the configured topic.

  ## Example

  The following map is an example of configuration that can be passed to a
  `LocalMessageQueue.Supervisor`:

      %{
        name_registry: MyApp.LocalMessageQueue.NameRegistry,
        message_registry: MyApp.LocalMessageQueue.MessageRegistry,
        id: MyApp.Producers.Double,
        cache_ttl: 5000,
        queue: %{filter_fun: {MyApp.Producers.Double, :positive_number?}},
        consumer: %{delay: nil},
        producer: MyApp.Producers.Double,
        subscription_key: MyApp.LocalMessageQueue.NewNumber,
        publisher_key: MyApp.LocalMessageQueue.DoubledNumber
      }

  This queue would listen for messages either dispatched by other LocalMessageQueues or another
  process using the `dispatch_new_msgs/3` fun with the right `:subscription_key`.
  LocalMessageQueues subscribing to this queue's `:publisher_key` would automatically register as
  listeners for those messages and other processes can register using the `listen/2` fun. This
  particular queue includes a filter that would filter out non-positive numbers.
  """

  @doc """
  Dispatches a message to all registered listeners.
  """
  @spec dispatch(Registry.registry(), any, any) :: :ok
  def dispatch(registry, key, msg) do
    Registry.dispatch(registry, key, fn listeners ->
      Enum.each(listeners, fn {pid, _} -> send(pid, msg) end)
    end)
  end

  @doc """
  Dispatch a message containing data to all registered listeners.
  """
  @spec dispatch_new_msgs(Registry.registry(), Registry.key(), list) :: :ok
  def dispatch_new_msgs(_, _, []), do: :ok

  def dispatch_new_msgs(registry, key, new_msgs) do
    msg = {:new_msgs, key, new_msgs}

    dispatch(registry, key, msg)
  end

  @doc """
  Registers the calling process as a listener of `registry`'s `key`.
  """
  @spec listen(Registry.registry(), any) :: :ok
  def listen(registry, key) do
    Registry.register(registry, key, nil)

    :ok
  end

  @doc """
  Registers calling process as a listener to all of `queue_id`'s queue messages.
  """
  @spec listen_to_queue(Registry.registry(), any) :: :ok
  def listen_to_queue(registry, queue_id) do
    Enum.each([:queue_add, :queue_remove], fn key_type ->
      listen(registry, {key_type, queue_id})
    end)
  end
end
