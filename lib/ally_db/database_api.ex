defmodule AllyDB.DatabaseAPI do
  @moduledoc """
  Provides the internal API for interacting with the sharded database layer.

  Handles routing requests to the appropriate ShardActor based on key hashing.
  Also responsible for initializing the shard actors on application start.
  """

  alias AllyDB.Core.ProcessManager
  alias AllyDB.Sharding

  require Logger

  @typedoc "The key used in the database."
  @type key :: any()

  @typedoc "The value stored in the database."
  @type value :: any()

  @typedoc "Possible error reasons returned by API functions."
  @type error_reason :: :not_found | :shard_unavailable | {:shard_crash, any()}

  @num_shards Application.compile_env(:allydb, :num_shards, 16)
  if !is_integer(@num_shards) or @num_shards < 1 do
    raise "Application environment :allydb, :num_shards must be a positive integer."
  end

  @doc """
  Retrieves the value associated with the given `key`.

  Routes the request to the appropriate shard actor.
  Returns `{:ok, value}` or `{:error, reason}` where `reason` includes
  `:not_found`, `:shard_unavailable`, or `{:shard_crash, exit_reason}`.
  """
  @spec get(key()) :: {:ok, value()} | {:error, error_reason()}
  def get(key) do
    case find_shard_pid(key) do
      {:ok, pid} ->
        try do
          GenServer.call(pid, {:get, key})
        rescue
          reason ->
            Logger.error(
              "Shard actor call exited for key '#{inspect(key)}'. PID: #{inspect(pid)}, Reason: #{inspect(reason)}"
            )

            {:error, {:shard_crash, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Sets the `value` for the given `key`.

  Routes the request to the appropriate shard actor. This operation is
  asynchronous from the caller's perspective. Returns `:ok` if the
  responsible shard is found (message sent), `{:error, :shard_unavailable}` otherwise.
  """
  @spec set(key(), value()) :: :ok | {:error, :shard_unavailable}
  def set(key, value) do
    case find_shard_pid(key) do
      {:ok, pid} ->
        GenServer.cast(pid, {:set, key, value})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes the given `key` and its associated value.

  Routes the request to the appropriate shard actor. This operation is
  asynchronous from the caller's perspective. Returns `:ok` if the
  responsible shard is found (message sent), `{:error, :shard_unavailable}` otherwise.
  """
  @spec delete(key()) :: :ok | {:error, :shard_unavailable}
  def delete(key) do
    case find_shard_pid(key) do
      {:ok, pid} ->
        GenServer.cast(pid, {:delete, key})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec find_shard_pid(key()) :: {:ok, pid()} | {:error, :shard_unavailable}
  defp find_shard_pid(key) do
    shard_id = Sharding.hash_key_to_shard(key, @num_shards)
    shard_process_id = "shard_#{shard_id}"

    case ProcessManager.lookup_process(shard_process_id) do
      [{pid, _value}] ->
        {:ok, pid}

      [] ->
        Logger.error(
          "Cannot find shard actor PID for key '#{inspect(key)}' (shard_id: #{shard_id}, registry_id: '#{shard_process_id}')"
        )

        {:error, :shard_unavailable}
    end
  end
end
