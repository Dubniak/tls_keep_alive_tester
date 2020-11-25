defmodule TLS_SERVER.SessionProtocol  do
  use GenServer
  require Logger


 def start_link(ref, socket, transport, opts) do
  GenServer.start_link(__MODULE__, [ref, socket, transport, opts])
end


def init([ref, socket, transport, opts]) do
  # Note: Because :ranch.handshake/1 is blocking, the init function must return instantly
  {:ok, {client_ip, port}} = :inet.peername(socket)
  Logger.info("New TLS connection attempt #{inspect(client_ip)} #{port}")
  state = %{
    ref:                  ref,
    socket:               socket,
    transport:            transport,
    stun_id:              nil,
    stun_key:             nil,
    media_port:           nil,
    hd_gw_media_port:     nil,
    tls_inactivity_timer: nil,
    registered?:          false,
    link_status:          nil,
    vp_status:            nil,
    radio_data:           nil,
    tcp_buffer:           <<>>
  }
  # {:ok, state}
  {:ok, state, {:continue, :handshake}}
end

def handle_continue(:handshake, state = %{socket: init_socket, ref: ref, transport: transport}) do
  # {:ok, {client_ip, port}} = :ssl.peername(init_socket)
  {:ok, socket} = :ranch.handshake(ref)
  Logger.info("Handshake succesful")
  tls_ready(transport, socket)
  {:noreply, %{state | socket: socket}}
end

def handle_info(msg, state) do
  Logger.info("Received #{inspect(msg)}")
  {:noreply, state}
end
def handle_info({protocol_closed, reason}, state)
  when protocol_closed in [:tcp_closed, :ssl_closed] do
Logger.debug "~p reason: ~p", [protocol_closed, reason]
cleanup(state)
{:stop, {:shutdown, protocol_closed}, state}
end

def handle_info({protocol, _, bin}, state = %{})
  when protocol in [:tcp, :ssl] do
Logger.debug "Received on ~p: ~p", [protocol, bin]
# tls_ready(transport, socket)
{:noreply, state}
end

defp tls_ready(transport, socket), do: :ok = transport.setopts(socket, [active: :once])

defp cleanup(%{transport: tr, socket: sock, stun_id: nil}) do
  _ok = tr.close(sock)
end

end
