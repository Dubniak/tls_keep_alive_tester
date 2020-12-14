defmodule TLS_CLIENT.Pool do
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # {:ok, server_ip} =
    #   "TCP_SERVER_IP"
    #   |> System.fetch_env!()
    #   |> to_charlist()
    #   |> :inet.parse_ipv4_address()

    # server_port = get_int_env("TCP_SERVER_PORT")
    # num_clients = get_int_env("TCP_CLIENT_COUNT")

    {:ok, server_ip} =
      "127.0.0.1"
      |> to_charlist()
      |> :inet.parse_ipv4_address()

    server_port = 49665
    num_clients = 1500

    worker_args = [server_ip: server_ip, server_port: server_port]
    children = Enum.map(1..num_clients, &(worker_spec(&1, worker_args)))
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp worker_spec(id, worker_args) do
    child_spec = {TLS_CLIENT.Worker, [{:client_id, id} | worker_args]}
    Supervisor.child_spec(child_spec, id: id)
  end

  defp get_int_env(env_var) do
    env_var |> System.fetch_env!() |> String.to_integer()
  end
end
