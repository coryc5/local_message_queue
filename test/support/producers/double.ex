defmodule LocalMessageQueue.Producers.Double do
  @behaviour LocalMessageQueue.Producer

  @impl true
  def call(input) when is_number(input) do
    {:ok, input * 2}
  end

  def call(_input) do
    {:error, :invalid_input}
  end
end
