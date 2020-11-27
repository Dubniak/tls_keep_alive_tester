defmodule TLS_CLIENT.Worker do
  use GenStateMachine
  require Logger

  alias TLS_CLIENT.Client

  @ka :timer.seconds(5) # milisecs

  def start_link(args) do
    GenStateMachine.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    data = %{
      server_ip:    Keyword.get(args, :server_ip),
      server_port:  Keyword.get(args, :server_port),
      client_id:    Keyword.get(args, :client_id),
      socket:       nil,
      local_port:   nil
    }
    # opts = [:binary, active: false]
    IO.puts "LALA #{inspect(data)}"

    init_delay = :rand.uniform(10)
    action = {{:timeout, :init}, init_delay, nil}
    {:ok, :init, data, action}
  end

  @impl true
  def handle_event({:timeout, :init}, _, _state, data) do
    Logger.info("Timeout before sending")
    {:ok, soc} = :gen_tcp.connect(data.server_ip, data.server_port, [:binary, {:active, true}])
    {:next_state, :open_socket, %{data | socket: soc}, {{:timeout, :send_request}, 0, nil}}
  end

  @impl true
  def handle_event({:timeout, :send_request}, _, :open_socket,  data) do
    Logger.info("Send init req")
    :ok = :gen_tcp.send(data.socket, "1.Send Request")
    {:next_state, :idle, data, {{:timeout, :send_request}, 0, nil}}
  end

  @impl true
  def handle_event({:timeout, :send_request}, _, :idle, data) do
    Logger.info("Wait for 60 seconds")
    ka_delay = @ka
    new_action = {{:timeout, :send_keep_alive}, @ka, nil}
    # new_action = {{:timeout, :send_keep_alive}, 0, nil}
    {:next_state, :keep_alive, data, new_action}
    # {:keep_state_and_data, :postpone}
  end

  @impl true
  def handle_event({:timeout, :send_keep_alive}, _, :keep_alive, data) do
    Logger.info("Sending keep alive")
    :ok = :gen_tcp.send(data.socket, "Keep Alive")
    new_action = {{:timeout, :send_request}, 0, nil}
    {:next_state, :idle, data, new_action }
  end

end
