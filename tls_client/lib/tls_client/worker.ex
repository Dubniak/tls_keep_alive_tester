defmodule TLS_CLIENT.Worker do
  use GenStateMachine
  require Logger

  @ka :timer.seconds(60)             #time between consequent Keep Alive requests
  @ka_timeout :timer.seconds(80)     #time upon clossing hanging connection

  def start_link(args) do
    GenStateMachine.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    data = %{
      server_ip:    Keyword.get(args, :server_ip),
      server_port:  Keyword.get(args, :server_port),
      client_id:    Keyword.get(args, :client_id),
      socket:       nil
    }
    init_delay = :rand.uniform(@ka)
    action = {{:timeout, :init}, init_delay, nil}
    {:ok, :init, data, action}
  end

  @impl true
  def handle_event({:timeout, :init}, _, _state, data) do
    Logger.info("Initialising client socket, client_id: #{(data.client_id)}")
    case :gen_tcp.connect(data.server_ip, data.server_port, [:binary, {:active, true}]) do
      {:ok, soc}      -> {:next_state, :open_socket, %{data | socket: soc}, {{:timeout, :send_request}, 0, nil}}
      {:error, error} ->  Logger.error("Error initialising client socket #{inspect(error)}")
                          action = {{:timeout, :init}, :rand.uniform(@ka), nil}
                          {:keep_state_and_data, action}
    end
  end

  @impl true
  def handle_event(:info, {:tcp, _socket, msg}, :keep_alive, data) do
    cond do
      msg == "Keep Alive Response" ->
              Logger.info("Received #{inspect(msg)}")
      true  ->
              Logger.error("Received #{inspect(msg)}")
    end
    new_action = {{:timeout, :send_keep_alive}, @ka, nil}
    {:next_state, :keep_alive, data, new_action}
  end

  @impl true
  def handle_event({:timeout, :send_request}, _, :open_socket,  data) do
    Logger.info("Establishing TCP session")
    :ok = :gen_tcp.send(data.socket, "Establish Session")
    {:next_state, :idle, data, {{:timeout, :send_request}, 0, nil}}
  end

  @impl true
  def handle_event({:timeout, :send_request}, _, :idle, data) do
    Logger.debug("Waiting for #{inspect(@ka)} miliseconds")
    new_action = {{:timeout, :send_keep_alive}, @ka, nil}
    {:next_state, :keep_alive, data, [new_action,{:state_timeout, @ka_timeout, :hold_timeout}]}
  end

  @impl true
  def handle_event({:timeout, :send_keep_alive}, _, :keep_alive, data) do
    Logger.info("Sending keep alive")
    :ok = :gen_tcp.send(data.socket, "Keep Alive")
    new_action = {{:timeout, :send_request}, 0, nil}
    {:next_state, :idle, data, new_action}
  end

  # Timeout for hanging connections
  @impl true
  def handle_event(:state_timeout, :hold_timeout, :keep_alive, data) do
    Logger.error("Keep Alive response not received. Closing connection")
    :gen_tcp.close(data.socket)
    action = {{:timeout, :init}, 0, nil}
    {:next_state, :init, data, action}
  end

  @impl true
  def handle_event(:info, {protocol_closed, reason}, state, _data) do
    Logger.error "Server terminated TCP connection, #{inspect(reason)}"
    {:stop, {:shutdown, protocol_closed}, state}
  end
end
