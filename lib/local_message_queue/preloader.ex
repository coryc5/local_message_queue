defmodule LocalMessageQueue.Preloader do
  @moduledoc """
  The `Preloader` subscribes to new messages and optionally checks to see if those messages have
  already been processed and stored in a `Cache` by a `Consumer`. Those cached results are
  dispatched as new messages and uncached messages are concatenated to the end of the Queue.
  """

  use GenServer

  @type config :: %{
          name: GenServer.name(),
          subscription_key: atom,
          publisher_key: atom,
          registry: Registry.registry(),
          cache: LocalMessageQueue.Cache.cache_name() | nil,
          queue: LocalMessageQueue.Queue.queue_name()
        }

  @doc false
  @spec start_link(config) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: config.name)
  end

  @impl true
  def init(config) do
    LocalMessageQueue.listen(config.registry, config.subscription_key)

    {:ok, config}
  end

  @impl true
  def handle_info({:new_msgs, _publisher, msgs}, %{cache: cache} = config) do
    {cached_results, uncached_msgs} =
      case cache do
        nil ->
          {[], msgs}

        cache ->
          {cached_msgs, uncached_msgs} =
            Enum.split_with(msgs, &LocalMessageQueue.Cache.get(cache, &1))

          cached_results =
            Enum.flat_map(cached_msgs, &LocalMessageQueue.Cache.get(config.cache, &1))

          {cached_results, uncached_msgs}
      end

    LocalMessageQueue.dispatch_new_msgs(config.registry, config.publisher_key, cached_results)
    LocalMessageQueue.Queue.concat(config.queue, uncached_msgs)

    {:noreply, config}
  end

  def handle_info(_, config) do
    {:noreply, config}
  end
end
