defmodule TLS_SERVER do
  require Logger
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    Logger.debug "Starting"
    start_listener(:tls)
    {:ok, %{}}
  end

  defp start_listener() do
    Logger.info "Starting TCP listener..."
    opts = ranch_opts(common_socket_opts())
    {:ok, _} = :ranch.start_listener(:Tcp, :ranch_tcp, opts, TLS_SERVER.SessionProtocol, cert_verification: false)
  end

  defp start_listener(:tls) do
    Log.info "Starting TLS listener..."
    opts = ranch_opts(common_socket_opts() ++ tls_socket_opts() ++ tls_cert_opts(CfgService.tls_ciphers()))
    {:ok, _} = ranch_start(tls_ref(), :ranch_ssl, opts)
  end

  defp ranch_opts(socket_opts), do: %{
    connection_type:      :supervisor,
    socket_opts:          socket_opts,
    max_connections:      30500,
    num_acceptors:        100,
    handshake_timeout:    20000
  }

  defp common_socket_opts, do:
  [
    port: 49665,
    tos: 0x88
  ]

  defp tls_socket_opts do
    key     = "../cert/privateKey.key"
    # cacerts = SubscriberService.Config.cacerts()
    crt     = "../cert/certificate.crt"
    # rate    = Session.Rate.ref()
    verify  = true
    [
      # cacerts:              cacerts,
      key:                  key,
      cert:                 crt,
      versions:             [:"tlsv1.2"],
      verify:               tls_client_verify(verify),
      fail_if_no_peer_cert: verify,
      reuse_sessions:       false,
      client_renegotiation: false,
      verify_fun:           {mk_verify_fun(rate), []}
    ]
  end

  defp tls_cert_opts(:restricted), do:
  [
    ciphers: [%{cipher: :aes_256_gcm, key_exchange: :ecdhe_ecdsa, mac: :aead, prf: :sha384},
    %{cipher: :aes_256_gcm, key_exchange: :ecdhe_rsa, mac: :aead, prf: :sha384},
    %{cipher: :aes_256_gcm, key_exchange: :rsa, mac: :aead, prf: :sha384}]
  ]

  defp tls_cert_opts(:unrestricted), do:
  [
    ciphers: :ssl.cipher_suites(:all,:'tlsv1.2')
  ]

  defp tls_client_verify(true), do: :verify_peer
  defp tls_client_verify(_),    do: :verify_none



end
