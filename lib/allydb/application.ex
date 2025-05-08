defmodule AllyDB.Application do
  @moduledoc false

  use Application

  require Logger

  defp grpc_port do
    Application.get_env(:allydb, :grpc)[:port]
  end

  @impl true
  def start(_type, _args) do
    port = grpc_port()
    Logger.info("Starting AllyDB gRPC server on port #{port}.")

    num_shards = Application.get_env(:allydb, :num_shards)

    unless is_integer(num_shards) and num_shards > 0 do
      raise "Configuration :allydb, :num_shards must be a positive integer"
    end

    shard_specs =
      for shard_id <- 0..(num_shards - 1) do
        %{
          id: {:shard_actor, shard_id},
          start: {AllyDB.ShardActor, :start_link, [{shard_id, %{}}]},
          restart: :transient
        }
      end

    children = [
      {Registry, keys: :unique, name: AllyDB.Registry},
      %{
        id: AllyDB.ShardSupervisor,
        start:
          {Supervisor, :start_link,
           [shard_specs, [strategy: :one_for_one, name: AllyDB.ShardSupervisor]]},
        type: :supervisor
      },
      AllyDB.DynamicSupervisor,
      {Task.Supervisor, name: AllyDB.SnapshotTaskSupervisor},
      {GRPC.Server.Supervisor,
       [endpoint: AllyDB.Network.Endpoint, port: port, start_server: true]}
    ]

    opts = [strategy: :one_for_one, name: AllyDB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
