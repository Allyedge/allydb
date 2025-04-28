import Config

config :allydb,
  num_shards: String.to_integer(System.get_env("ALLYDB_SHARDS", "4")),
  grpc: [
    port: String.to_integer(System.get_env("ALLYDB_GRPC_PORT", "50051"))
  ]
