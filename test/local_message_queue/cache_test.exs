defmodule LocalMessageQueue.CacheTest do
  use ExUnit.Case, async: true

  alias LocalMessageQueue.Cache

  @expiration_ms 200

  setup do
    registry = __MODULE__.Registry
    start_supervised!({Registry, keys: :unique, name: registry})

    name = {:via, Registry, {registry, System.unique_integer([:monotonic])}}

    start_supervised!({Cache, {name, @expiration_ms}})

    %{name: name}
  end

  test "returns nil if no value exists under key", %{name: name} do
    assert Cache.get(name, :some_key) |> is_nil()
  end

  test "returns value if key exists", %{name: name} do
    key = :some_key
    value = [:some_value]

    :ok = Cache.put(name, key, value)

    assert Cache.get(name, key) == value
  end

  test "returns nil if item has expired", %{name: name} do
    key = :some_key
    value = [:some_value]

    :ok = Cache.put(name, key, value)

    :timer.sleep(@expiration_ms + 1)

    assert Cache.get(name, key) |> is_nil()
  end
end
