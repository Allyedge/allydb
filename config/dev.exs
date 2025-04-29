import Config

config :allydb,
  num_shards: String.to_integer(System.get_env("ALLYDB_SHARDS", "4")),
  grpc: [
    port: String.to_integer(System.get_env("ALLYDB_GRPC_PORT", "50051"))
  ],
  persistence: [
    snapshot_dir:
      System.get_env("ALLYDB_SNAPSHOT_DIR", "../priv/snapshots")
      |> Path.expand(__DIR__),
    snapshot_interval: String.to_integer(System.get_env("ALLYDB_SNAPSHOT_INTERVAL", "5000"))
  ]
