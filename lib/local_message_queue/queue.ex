defmodule LocalMessageQueue.Queue do
  @moduledoc """
  Process for managing a queue.
  """

  use GenServer

  @type queue_name :: GenServer.name()
  @type filter_fun :: {module, fun}
  @type config :: %{
          id: atom,
          name: queue_name,
          registry: Registry.registry(),
          filter: filter_fun | nil
        }

  @type state :: %{
          id: atom,
          name: queue_name,
          registry: Registry.registry(),
          filter: filter_fun | nil,
          queue: [any],
          pre_queue_stack: [any]
        }

  @doc false
  @spec start_link(config) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: config.name)
  end

  @impl true
  def init(config) do
    state = Map.merge(config, %{queue: [], pre_queue_stack: []})

    {:ok, state}
  end

  @doc """
  Adds `list` to the end of `queue`.

  Also dispatches a `{:queue_add, queue_name}` message for any registered listeners.
  """
  @spec concat(queue_name, [any]) :: [any]
  def concat(queue, list) do
    GenServer.call(queue, {:concat, list})
  end

  @doc """
  Returns the first item in `queue` and removes it from the internal queue.

  Also dispatches a `{:queue_remove, queue_name}` message for any registered listeners.
  """
  @spec pop(queue_name) :: any
  def pop(queue) do
    GenServer.call(queue, :pop)
  end

  @doc """
  Returns the length of `queue`.
  """
  @spec len(queue_name) :: non_neg_integer
  def len(queue) do
    GenServer.call(queue, :len)
  end

  @impl true
  def handle_call({:concat, list}, _from, state) do
    filtered_list = maybe_filter_list(list, state.filter)

    new_state = %{state | pre_queue_stack: Enum.reverse(filtered_list) ++ state.pre_queue_stack}

    LocalMessageQueue.dispatch(state.registry, {:queue_add, state.id}, {:queue_add, state.name})

    {:reply, new_state.pre_queue_stack, new_state}
  end

  def handle_call(:pop, _from, state) do
    {item, remaining_queue, pre_queue_stack} = handle_pop(state)
    new_state = %{state | queue: remaining_queue, pre_queue_stack: pre_queue_stack}

    unless item == :empty do
      LocalMessageQueue.dispatch(
        state.registry,
        {:queue_remove, state.id},
        {:queue_remove, state.name}
      )
    end

    {:reply, item, new_state}
  end

  def handle_call(:len, _from, state) do
    total_length = length(state.queue) + length(state.pre_queue_stack)

    {:reply, total_length, state}
  end

  @spec handle_pop(state) :: {any, queue :: list, pre_queue_stack :: list}
  defp handle_pop(%{queue: [], pre_queue_stack: []}), do: {:empty, [], []}

  defp handle_pop(%{queue: [], pre_queue_stack: pre_queue_stack}) do
    [item | remaining_queue] = Enum.reverse(pre_queue_stack)

    {item, remaining_queue, []}
  end

  defp handle_pop(%{queue: [item | remaining_queue], pre_queue_stack: pre_queue_stack}),
    do: {item, remaining_queue, pre_queue_stack}

  @spec maybe_filter_list([any], filter_fun | nil) :: [any]
  defp maybe_filter_list(list, filter) do
    case filter do
      nil -> list
      {module, fun} -> Enum.filter(list, fn val -> apply(module, fun, [val]) end)
    end
  end
end
