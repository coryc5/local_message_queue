defmodule LocalMessageQueue.SupervisorTest do
  use ExUnit.Case, async: true

  @name_registry __MODULE__.NameRegistry
  @msg_registry __MODULE__.MsgRegistry
  @id __MODULE__
  @subscription_key __MODULE__.NewNumber
  @publisher_key __MODULE__.Doubled

  setup do
    start_supervised!({Registry, keys: :unique, name: @name_registry})
    start_supervised!({Registry, keys: :duplicate, name: @msg_registry})

    config = %{
      name_registry: @name_registry,
      message_registry: @msg_registry,
      id: @id,
      cache_ttl: nil,
      queue: %{},
      consumer: %{delay: nil},
      producer: LocalMessageQueue.Producers.Double,
      subscription_key: @subscription_key,
      publisher_key: @publisher_key
    }

    start_supervised!({LocalMessageQueue.Supervisor, config})

    :ok
  end

  test "integration" do
    # listen for published msgs
    LocalMessageQueue.listen(@msg_registry, @publisher_key)

    input = [1, 2, 3]

    # dispatch a msg
    LocalMessageQueue.dispatch_new_msgs(@msg_registry, @subscription_key, input)

    # consumer should dispatch input doubled per the producer
    Enum.each(input, fn msg ->
      result = msg * 2

      assert_receive({:new_msgs, @publisher_key, [^result]})
    end)
  end
end
