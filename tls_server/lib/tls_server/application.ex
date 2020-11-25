defmodule TLS_SERVER.Application do
  use Application

  def start(_type, _args) do
    children = [
      TLS_SERVER
    ]

    opts = [strategy: :one_for_one, name: TLS_SERVER.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
