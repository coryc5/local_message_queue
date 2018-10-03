defmodule LocalMessageQueue do
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
