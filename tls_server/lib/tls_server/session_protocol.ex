defmodule TLS_SERVER.SessionProtocol  do
  use GenServer
  require Logger

  @tls_it :timer.seconds(10)   #tls_inactivity_threshold

  @short_msg  << "Short message reply",
                  256   :: size(256) >>   # bit_size 408
  @long_msg   << "Long message reply",
                  1024   :: size(1024) >>  # bit_size 1168

  def start_link(ref, socket, transport, opts) do
    GenServer.start_link(__MODULE__, [ref, socket, transport, opts])
  end

  def reset_timer() do
    GenServer.call(__MODULE__, :reset_timer)
  end

  def init([ref, socket, transport, _opts]) do
    {:ok, {client_ip, port}} = :ssl.peername(socket)
    Logger.info("New TCP connection attempt #{inspect(client_ip)}:#{port}")
    state = %{
      ref:                  ref,
      socket:               socket,
      transport:            transport,
      client_port:          port,
      client_ip:            client_ip,
      timer:                nil
    }
    {:ok, state, {:continue, :handshake}}
  end

  def handle_continue(:handshake, state = %{ref: ref, transport: transport, client_port: client_port, client_ip: client_ip}) do
    {:ok, socket} = :ranch.handshake(ref)
    Logger.debug("Handshake succesful #{inspect(client_ip)}:#{inspect(client_port)}")
    new_state = timer_reset(state)
    tls_ready(transport, socket)
    {:noreply, %{new_state | socket: socket}}
  end

  def handle_info({protocol_closed, _reason}, state = %{client_port: client_port, client_ip: client_ip})
    when protocol_closed in [:tcp_closed, :ssl_closed] do
  Logger.info "Terminating TCP connection from #{inspect(client_ip)}:#{inspect(client_port)} #{inspect(protocol_closed)} "
  cleanup(state)
  {:stop, {:shutdown, protocol_closed}, state}
end

  def handle_info({protocol, _, msg}, state = %{socket: socket, client_port: client_port, client_ip: client_ip}) do
    cond do
      msg == "Keep Alive"
                          -> Logger.debug "R: #{inspect(msg)}, from #{inspect(client_ip)}:#{inspect(client_port)} #{inspect(protocol)}"
                             new_state = timer_reset(state)
                             :ssl.send(socket, "Keep Alive Response") #add :ok
                             Logger.debug("S: Keep Alive Response to #{inspect(client_ip)}:#{inspect(client_port)}")
                             {:noreply, new_state}
      msg == "Establish Session"
                          -> Logger.debug("R: #{inspect(msg)}, from #{inspect(client_ip)}:#{inspect(client_port)} #{inspect(protocol)}")
                          {:noreply, state}
      true
                          ->
                              case bit_size(msg) do
                                360   ->
                                  Logger.debug("S: Short message reply, #{inspect(client_ip)}:#{inspect(client_port)} #{inspect(protocol)}")
                                  :ssl.send(socket, @short_msg)
                                1120  ->
                                  Logger.debug("S: Long message reply, #{inspect(client_ip)}:#{inspect(client_port)} #{inspect(protocol)}")
                                  :ssl.send(socket, @long_msg)
                                n when n in [496, 1256] ->
                                  Logger.debug("R: Handshake message")
                                _     ->
                                  Logger.error("R: #{inspect(msg)}, #{inspect(client_ip)}:#{inspect(client_port)} #{inspect(protocol)}")
                              end
                          {:noreply, state}
    end
  end

  def handle_info(:close_hanging_connection, state = %{socket: socket, client_port: client_port, client_ip: client_ip}) do
    Logger.error("Keep alive request not received #{inspect(client_ip)}:#{inspect(client_port)}, #{inspect(socket)}")
    Logger.info("Terminating TCP connection from #{inspect(client_ip)}:#{inspect(client_port)} :keep_alive_missing")
    {:stop, :shutdown, cleanup(state)}
  end

  def handle_info(msg, state) do
    Logger.debug("Received #{inspect(msg)}")
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

  defp cleanup(_state = %{transport: tr, socket: socket, client_port: client_port, client_ip: client_ip}) do
    _ok = tr.close(socket)
    Logger.debug("Cleanning up socket #{inspect(socket)}, #{inspect(client_ip)}:#{inspect(client_port)}")
  end
  defp cleanup(_state) do
    # Client shut down
   :ok
  end

end
