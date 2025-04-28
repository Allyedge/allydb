# lib/allydb/shard_initializer.ex
defmodule AllyDB.ShardInitializer do
  @moduledoc """
  A GenServer responsible for starting the database shard actors during application boot.

  It ensures that shard startup is part of the main supervision tree,
  halting application startup if shards cannot be initialized correctly.
  """

  use GenServer
  require Logger

  alias AllyDB.Core.ProcessManager
  alias AllyDB.ShardActor

  @num_shards Application.compile_env(:allydb, :num_shards, 16)
  if !is_integer(@num_shards) or @num_shards < 1 do
    raise "Application environment :allydb, :num_shards must be a positive integer."
  end

  @doc """
  Starts the ShardInitializer GenServer. Called by the application supervisor.
  """
  @spec start_link(_opts :: any()) :: GenServer.on_start()
  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Initializes the ShardInitializer. Called by `start_link`.

  Attempts to start all configured shard actors. Returns `{:ok, state}` on
  success, or `{:stop, reason}` if shard initialization fails, which halts
  the application startup.
  """
  @impl GenServer
  @spec init(_opts :: map()) :: {:ok, map()} | {:stop, term()}
  def init(_init_arg) do
    Logger.info("ShardInitializer starting...")

    case start_shards() do
      :ok ->
        Logger.info(
          "ShardInitializer finished: All #{@num_shards} shard actors started or already running."
        )

        {:ok, %{}}

      {:error, reason} ->
        Logger.critical(
          "ShardInitializer failed: Could not start all shards. Reason: #{inspect(reason)}"
        )

        {:stop, {:shard_initialization_failed, reason}}
    end
  end

  @spec start_shards() ::
          :ok | {:error, {:failed_to_start_shard, non_neg_integer(), any()}}
  defp start_shards do
    Logger.info("Starting #{@num_shards} shard actors...")

    Enum.reduce_while(0..(@num_shards - 1), :ok, fn shard_id, _acc ->
      shard_process_id = "shard_#{shard_id}"

      case ProcessManager.start_process(shard_process_id, ShardActor, {shard_id, %{}}) do
        {:ok, _pid} ->
          Logger.debug("ShardActor [#{shard_id}]: Started successfully.")
          {:cont, :ok}

        {:error, {:already_started, _pid}} ->
          Logger.warning("ShardActor [#{shard_id}]: Already started.")
          {:cont, :ok}

        {:error, reason} ->
          error_detail = {:failed_to_start_shard, shard_id, reason}
          Logger.error("ShardActor [#{shard_id}]: Failed to start. Reason: #{inspect(reason)}")
          {:halt, {:error, error_detail}}
      end
    end)
  end
end
