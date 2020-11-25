defmodule TLS_CLIENT.Pool do
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Supervisor.init(children, strategy: :one_for_one)
  end

end
