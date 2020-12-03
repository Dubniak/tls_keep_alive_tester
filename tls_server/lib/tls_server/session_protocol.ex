defmodule TLS_SERVER.SessionProtocol  do
  use GenServer
  require Logger

  @tls_it :timer.seconds(8)   #tls_inactivity_threshold

  def start_link(ref, socket, transport, opts) do
    GenServer.start_link(__MODULE__, [ref, socket, transport, opts])
  end

  def reset_timer() do
    GenServer.call(__MODULE__, :reset_timer)
  end

  def init([ref, socket, transport, _opts]) do
    {:ok, {client_ip, port}} = :inet.peername(socket)
    Logger.info("New TCP connection attempt #{inspect(client_ip)} #{port}")
    state = %{
      ref:                  ref,
      socket:               socket,
      transport:            transport,
      client_port:          port,
      timer:                nil
    }
    {:ok, state, {:continue, :handshake}}
  end

  def handle_continue(:handshake, state = %{ref: ref, transport: transport, client_port: client_port}) do
    {:ok, socket} = :ranch.handshake(ref)
    Logger.info("Handshake succesful, client port #{inspect(client_port)}")
    new_state = timer_reset(state)
    tls_ready(transport, socket)
    {:noreply, %{new_state | socket: socket}}
  end

  def handle_info({protocol_closed, reason}, state)
    when protocol_closed in [:tcp_closed, :ssl_closed] do
    Logger.info "Terminating TCP connection, client port #{inspect(state.client_port)}, #{inspect(reason)}"
    cleanup(state)
    {:stop, {:shutdown, protocol_closed}, state}
  end

  def handle_info({protocol, _, msg}, state = %{socket: socket, client_port: client_port}) do
    cond do
      msg == "Keep Alive"
                          -> Logger.info "R: #{inspect(msg)}, client port #{inspect(client_port)} #{inspect(protocol)}"
                             new_state = timer_reset(state)
                             :gen_tcp.send(socket, "Keep Alive Response")
                             Logger.info("S: Keep Alive Response to #{inspect(client_port)}")
                             {:noreply, new_state}
      msg == "Establish Session"
                          -> Logger.info("R: #{inspect(msg)}, client port #{inspect(client_port)} #{inspect(protocol)}")
                          {:noreply, state}
      true                -> Logger.error("R: #{inspect(msg)}, client port #{inspect(client_port)} #{inspect(protocol)}")
                          {:noreply, state}
    end
  end

  def handle_info(:close_hanging_connection, state = %{socket: socket, client_port: client_port}) do
    Logger.error("Closing connection on socket #{inspect(socket)}, client port #{inspect(client_port)}")
    {:stop, :shutdown, cleanup(state)}
  end

  def handle_info(msg, state) do
    Logger.info("Received #{inspect(msg)}")
    {:noreply, state}
  end

  defp timer_reset(state = %{timer: timer}) do
    if timer do
      Process.cancel_timer(timer)
    end
    timer = Process.send_after(self(), :close_hanging_connection, @tls_it)
    %{state | timer: timer}
  end

  defp tls_ready(transport, socket), do: :ok = transport.setopts(socket, [active: :true])

  defp cleanup(_state = %{transport: tr, socket: socket, client_port: client_port}) do
    _ok = tr.close(socket)
    Logger.info("Cleanning up socket #{inspect(socket)}, client port #{inspect(client_port)}")
  end
  defp cleanup(_state) do
    # Client shut down
   :ok
  end

end
