defmodule LocalMessageQueue.Supervisor do
  @moduledoc false

  use Supervisor

  alias LocalMessageQueue.{Cache, Consumer, Preloader, Producer, Queue}

  @type config :: %{
          name_registry: Registry.registry(),
          message_registry: Registry.registry(),
          id: atom,
          cache_ttl: pos_integer | nil,
          queue: map,
          consumer: map,
          producer: Producer.t(),
          subscription_key: atom,
          publisher_key: atom,
          strategy: Supervisor.strategy()
        }

  @spec start_link(config) :: Supervisor.on_start()
  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: config.id)
  end

  @impl true
  def init(config) do
    children = [
      {Queue, queue_config(config)},
      {Consumer, consumer_config(config)},
      {Preloader, preloader_config(config)}
    ]

    children_with_cache = cache_children(children, config)
    Supervisor.init(children_with_cache, strategy: Map.get(config, :strategy, :one_for_one))
  end

  @spec child_spec(config) :: Supervisor.child_spec()
  def child_spec(config) do
    %{
      id: config.id,
      start: {__MODULE__, :start_link, [config]},
      type: :supervisor
    }
  end

  @spec cache_children([{module, term}], config) :: [{module, term}]
  defp cache_children(other_children, %{cache_ttl: nil}), do: other_children

  defp cache_children(other_children, %{cache_ttl: ttl} = config) do
    [{Cache, {name(config, Cache), ttl}} | other_children]
  end

  @spec queue_config(config) :: Queue.config()
  defp queue_config(%{queue: queue} = config) do
    %{
      id: config.id,
      name: name(config, Queue),
      registry: config.message_registry,
      filter: Map.get(queue, :filter_fun)
    }
  end

  @spec consumer_config(config) :: Consumer.config()
  defp consumer_config(%{consumer: consumer} = config) do
    %{
      id: config.id,
      name: name(config, Consumer),
      registry: config.message_registry,
      producer: config.producer,
      publisher_key: config.publisher_key,
      queue_name: name(config, Queue),
      delay: Map.get(consumer, :delay),
      cache: config.cache_ttl && name(config, Cache)
    }
  end

  @spec preloader_config(config) :: Preloader.config()
  defp preloader_config(config) do
    %{
      name: name(config, Preloader),
      registry: config.message_registry,
      subscription_key: config.subscription_key,
      publisher_key: config.publisher_key,
      queue: name(config, Queue),
      cache: config.cache_ttl && name(config, Cache)
    }
  end

  @spec name(config, atom) :: {:via, Registry, any}
  defp name(config, process_type) do
    {:via, Registry, {config.name_registry, {config.id, process_type}}}
  end
end
