defmodule AllyDB.DatabaseAPI do
  @moduledoc """
  Provides the internal API for interacting with the sharded database layer.

  Handles routing requests to the appropriate ShardActor based on key hashing.
  Also responsible for initializing the shard actors on application start.
  """

  alias AllyDB.Core.ProcessManager
  alias AllyDB.ShardActor

  require Logger

  @num_shards Application.compile_env(:allydb, :num_shards, 16)
  if !is_integer(@num_shards) or @num_shards < 1 do
    raise "Application environment :allydb, :num_shards must be a positive integer."
  end

  @doc """
  Starts the configured number of ShardActor processes.
  """
  def start_shards do
    Logger.info("Starting #{@num_shards} shard actors...")

    Enum.each(0..(@num_shards - 1), fn shard_id ->
      shard_process_id = "shard_#{shard_id}"

      case ProcessManager.start_process(shard_process_id, ShardActor, {shard_id, %{}}) do
        {:ok, _pid} ->
          Logger.debug("ShardActor [#{shard_id}] started successfully.")

        {:error, {:already_started, _pid}} ->
          Logger.warning("ShardActor [#{shard_id}] already started.")

        {:error, reason} ->
          Logger.error("Failed to start ShardActor for shard #{shard_id}: #{inspect(reason)}")
      end
    end)

    Logger.info("Shard actors startup sequence complete.")
    :ok
  end
end
