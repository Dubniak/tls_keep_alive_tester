defmodule TLS_CLIENT do
  require Logger
  use GenStateMachine

  alias TLS_CLIENT.Client
  @moduledoc """
  Documentation for `TLS_CLIENT`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> TLS_CLIENT.hello()
      :world

  """

  def start_link(args) do
    GenStateMachine.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    
  end

end
