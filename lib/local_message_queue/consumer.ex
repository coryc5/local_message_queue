defmodule LocalMessageQueue.Consumer do
  use GenServer

  @type config :: %{
          id: atom,
          name: GenServer.name(),
          registry: Registry.registry(),
          callback: {module, fun},
          publisher_key: atom,
          delay: pos_integer | nil,
          cache: atom | nil
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
  def handle_continue({:queue_add, queue_name}, config) do
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
  defp handle_data(queue_name, %{callback: {mod, fun}} = config) do
    case LocalMessageQueue.Queue.pop(queue_name) do
      :empty ->
        {:noreply, config}

      value ->
        if config.delay, do: :timer.sleep(config.delay)

        new_msgs = apply(mod, fun, [value]) |> List.wrap()

        if config.cache, do: LocalMessageQueue.Cache.put(config.cache, value, new_msgs)

        LocalMessageQueue.dispatch_new_msgs(config.registry, config.publisher_key, new_msgs)

        {:noreply, config, {:continue, {:queue_add, queue_name}}}
    end
  end
end
