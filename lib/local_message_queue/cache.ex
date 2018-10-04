defmodule LocalMessageQueue.Cache do
  @moduledoc """
  Map-based cache with an experation measured in milliseconds.
  """

  use Agent

  @type cache_name :: Agent.name()

  @doc false
  @spec start_link({cache_name, pos_integer}) :: Agent.on_start()
  def start_link({name, expiration_ms}) do
    Agent.start_link(fn -> %{cache: %{}, expiration_ms: expiration_ms} end, name: name)
  end

  @doc """
  Adds `values` to the cache under `key`.
  """
  @spec put(cache_name, any, list) :: :ok
  def put(cache_name, key, values) when is_list(values) do
    Agent.update(cache_name, fn %{cache: cache, expiration_ms: expiration_ms} ->
      now = get_now()
      new_cache = Map.put(cache, key, {values, now + expiration_ms})

      %{cache: new_cache, expiration_ms: expiration_ms}
    end)
  end

  @doc """
  Returns the cache's values under `key` if it exists and has not expired.
  """
  @spec get(cache_name, any) :: list
  def get(cache_name, key) do
    now = get_now()

    Agent.get_and_update(cache_name, fn %{cache: cache} = state ->
      case Map.get(cache, key) do
        nil ->
          {nil, state}

        {_val, expiration} when expiration < now ->
          updated_cache = Map.delete(cache, key)

          {nil, %{state | cache: updated_cache}}

        {value, _expiration} ->
          {value, state}
      end
    end)
  end

  @spec get_now :: pos_integer
  defp get_now do
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end
end
