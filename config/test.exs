import Config

config :allydb,
  num_shards: String.to_integer(System.get_env("ALLYDB_TEST_SHARDS", "4")),
  grpc: [
    port: String.to_integer(System.get_env("ALLYDB_GRPC_TEST_PORT", "50052"))
  ],
  persistence: [
    snapshot_dir:
      System.get_env("ALLYDB_SNAPSHOT_TEST_DIR", "../priv/test-snapshots")
      |> Path.expand(__DIR__),
    snapshot_interval: String.to_integer(System.get_env("ALLYDB_SNAPSHOT_TEST_INTERVAL", "5000"))
  ]
