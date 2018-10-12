defmodule LocalMessageQueue.Consumer do
  use GenServer

  @type config :: %{
          id: atom,
          name: GenServer.name(),
          registry: Registry.registry(),
          producer: LocalMessageQueue.Producer.t(),
          publisher_key: atom,
          delay: pos_integer | nil,
          cache: LocalMessageQueue.Cache.cache_name() | nil
        }

  @spec start_link(config) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: config.name)
  end

  @impl true
  def init(config) do
    LocalMessageQueue.listen_to_queue(config.registry, config.id)

    {:ok, config}
  end

  @impl true
  def handle_continue({:read_queue, queue_name}, config) do
    handle_data(queue_name, config)
  end

  @impl true
  def handle_info({:queue_add, queue_name}, config) do
    handle_data(queue_name, config)
  end

  def handle_info(_, config) do
    {:noreply, config}
  end

  @spec handle_data(atom, config) ::
          {:noreply, config} | {:noreply, config, {:continue, {:new_msgs, [any]}}}
  defp handle_data(queue_name, %{producer: producer} = config) do
    case LocalMessageQueue.Queue.pop(queue_name) do
      :empty ->
        {:noreply, config}

      value ->
        if config.delay, do: :timer.sleep(config.delay)

        case producer.call(value) do
          {:ok, new_msgs} ->
            new_msgs = List.wrap(new_msgs)

            if config.cache do
              LocalMessageQueue.Cache.put(config.cache, value, new_msgs)
            end

            LocalMessageQueue.dispatch_new_msgs(config.registry, config.publisher_key, new_msgs)

          {:error, _error} = e ->
            LocalMessageQueue.dispatch(config.registry, config.publisher_key, e)
        end

        {:noreply, config, {:continue, {:read_queue, queue_name}}}
    end
  end
end
