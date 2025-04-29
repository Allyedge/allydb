defmodule AllyDB.Application do
  @moduledoc false

  use Application

  require Logger

  @grpc_port Application.compile_env!(:allydb, :grpc)[:port]

  @impl true
  def start(_type, _args) do
    Logger.info("Starting AllyDB gRPC server on port #{@grpc_port}.")

    children = [
      %{
        id: AllyDB.Registry,
        start: {Registry, :start_link, [[keys: :unique, name: AllyDB.Registry]]}
      },
      AllyDB.DynamicSupervisor,
      AllyDB.ShardInitializer,
      {GRPC.Server.Supervisor,
       [
         endpoint: AllyDB.Network.Endpoint,
         port: @grpc_port,
         start_server: true
       ]}
    ]

    opts = [strategy: :one_for_one, name: AllyDB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
