defmodule TLS_CLIENT.Application do
  use Application

  def start(_type, _args) do
    children = [
      TLS_CLIENT.Pool
    ]
    opts = [strategy: :one_for_one, name: TLS_CLIENT.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
