defmodule TLS_SERVER do
  require Logger
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.debug "Starting"
    start_listener()
    {:ok, %{}}
  end

  defp start_listener() do
    Logger.info "Starting TCP listener..."
    opts = ranch_opts(common_socket_opts())
    {:ok, _} = :ranch.start_listener(:Tcp, :ranch_tcp, opts, TLS_SERVER.SessionProtocol, cert_verification: false)

  end

  defp ranch_opts(socket_opts), do: %{
    connection_type:      :supervisor,
    socket_opts:          socket_opts,
    max_connections:      3500,
    num_acceptors:        100,
    handshake_timeout:    20000
  }

  defp common_socket_opts, do:
  [
    port: 49665,
    tos: 0x88
  ]
end
