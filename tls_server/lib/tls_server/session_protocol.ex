defmodule TLS_SERVER.SessionProtocol  do
  use GenServer
  require Logger

  @tls_it :timer.seconds(3)   #tls_inactivity_threshold

  def start_link(ref, socket, transport, opts) do
    GenServer.start_link(__MODULE__, [ref, socket, transport, opts])
  end

  def init([ref, socket, transport, _opts]) do
    {:ok, {client_ip, port}} = :inet.peername(socket)
    Logger.info("New TLS connection attempt #{inspect(client_ip)} #{port}")
    state = %{
      ref:                  ref,
      socket:               socket,
      transport:            transport,
      tls_inactivity_timer: nil,
      registered?:          false,
      link_status:          nil,
      tcp_buffer:           <<>>
    }
    # IO.inspect(self())
    {:ok, state, {:continue, :handshake}}
  end

  def handle_continue(:handshake, state = %{ref: ref, transport: transport}) do
    {:ok, socket} = :ranch.handshake(ref)
    Logger.info("Handshake succesful")
    tls_ready(transport, socket)
    {:noreply, %{state | socket: socket}}
  end


  def handle_info({protocol_closed, reason}, state)
    when protocol_closed in [:tcp_closed, :ssl_closed] do
    Logger.info "~p reason: ~p", [protocol_closed, reason]
    cleanup(state)
    {:stop, {:shutdown, protocol_closed}, state}
  end
  def handle_info({protocol, _, bin}, state = %{socket: socket, transport: transport}) do
    Logger.info "Received on #{inspect(protocol)} #{inspect(bin)}"
    tls_ready(transport, socket)
    {:noreply, state}
  end
  def handle_info(msg, state) do
    Logger.info("Received #{inspect(msg)}")
    {:noreply, state}
  end

  defp tls_ready(transport, socket), do: :ok = transport.setopts(socket, [active: :once])

  defp cleanup(%{transport: tr, socket: sock, stun_id: nil}) do
    _ok = tr.close(sock)
  end

end
