defmodule TpxServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TpxServerWeb.Telemetry,
      TpxServer.Repo,
      {DNSCluster, query: Application.get_env(:tpx_server, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TpxServer.PubSub},
      TpxServerWeb.Presence,
      {Cluster.Supervisor,
       [
         Application.get_env(:tpx_server, :cluster_topologies, []),
         [name: TpxServer.ClusterSupervisor]
       ]},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TpxServer.Finch},
      # Start a worker by calling: TpxServer.Worker.start_link(arg)
      # {TpxServer.Worker, arg},
      # Start to serve requests, typically the last entry
      TpxServerWeb.Endpoint,
      TpxServer.TCPServer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TpxServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TpxServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
