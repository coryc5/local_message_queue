defmodule LocalMessageQueue.Producer do
  @moduledoc """
  Behaviour for producing new messages from a given input.
  """

  @type t :: module

  @callback call(any) :: {:ok, any} | {:error, any}
end
