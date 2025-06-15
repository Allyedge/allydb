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

  @typedoc "Additional error reasons for list operations."
  @type list_error_reason :: error_reason() | :empty_list | :index_out_of_range

  defp num_shards do
    case Application.get_env(:allydb, :num_shards) do
      n when is_integer(n) and n > 0 ->
        n

      other ->
        raise "Configuration :allydb, :num_shards must be a positive integer, got: #{inspect(other)}"
    end
  end

  @doc """
  Retrieves the value associated with the given `key`.

  Performs a direct ETS lookup on the appropriate shard table for low-latency reads.
  Falls back to a GenServer call if the ETS table is not yet available.
  Returns `{:ok, value}` or `{:error, reason}`, where `reason` may be:
    * `:not_found` (key missing in ETS),
    * `:shard_unavailable` (shard process not running),
    * `{:shard_crash, reason}` (shard process crashed during call).
  """
  @spec get(key :: key()) :: {:ok, value()} | {:error, error_reason()}
  def get(key) do
    shard_id = Sharding.hash_key_to_shard(key, num_shards())
    table = :"shard_#{shard_id}_table"

    case safe_ets_lookup(table, key) do
      {:ok, value} ->
        {:ok, value}

      :not_found ->
        {:error, :not_found}

      :no_table ->
        do_get_via_server(key)
    end
  end

  defp do_get_via_server(key) do
    case find_shard_pid(key) do
      {:ok, pid} ->
        try do
          GenServer.call(pid, {:get, key})
        catch
          :exit, reason ->
            Logger.error(
              "Shard actor exited for key '#{inspect(key)}'. PID: #{inspect(pid)}, Reason: #{inspect(reason)}"
            )

            {:error, {:shard_crash, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp safe_ets_lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :not_found
    end
  catch
    :error, :badarg -> :no_table
    :exit, _ -> :no_table
  end

  @doc """
  Sets the `value` for the given `key`.

  Routes the request to the appropriate shard actor. This operation is
  asynchronous from the caller's perspective. Returns `:ok` if the
  responsible shard is found (message sent), `{:error, :shard_unavailable}` otherwise.
  """
  @spec set(key :: key(), value :: value()) :: :ok | {:error, :shard_unavailable}
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
  @spec delete(key :: key()) :: :ok | {:error, :shard_unavailable}
  def delete(key) do
    case find_shard_pid(key) do
      {:ok, pid} ->
        GenServer.cast(pid, {:delete, key})
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Pushes one or more `values` to the left (head) of the list stored at `key`.

  Returns `{:ok, new_length}` where `new_length` is the new length of the list,
  or `{:error, reason}` where `reason` may be any of the standard error reasons.
  """
  @spec lpush(key :: key(), values :: [value()]) ::
          {:ok, non_neg_integer()} | {:error, error_reason()}
  def lpush(key, values) when is_list(values) and length(values) > 0 do
    do_list_operation_sync(key, {:lpush, values})
  end

  @doc """
  Pushes one or more `values` to the right (tail) of the list stored at `key`.

  Returns `{:ok, new_length}` where `new_length` is the new length of the list,
  or `{:error, reason}` where `reason` may be any of the standard error reasons.
  """
  @spec rpush(key :: key(), values :: [value()]) ::
          {:ok, non_neg_integer()} | {:error, error_reason()}
  def rpush(key, values) when is_list(values) and length(values) > 0 do
    do_list_operation_sync(key, {:rpush, values})
  end

  @doc """
  Removes and returns the first element from the left (head) of the list stored at `key`.

  Returns `{:ok, value}` if an element was popped, or `{:error, reason}` where
  `reason` may be `:not_found` (key doesn't exist), `:empty_list` (list exists but is empty),
  or any of the standard error reasons.
  """
  @spec lpop(key :: key()) :: {:ok, value()} | {:error, list_error_reason()}
  def lpop(key) do
    do_list_operation_sync(key, :lpop)
  end

  @doc """
  Removes and returns the first element from the right (tail) of the list stored at `key`.

  Returns `{:ok, value}` if an element was popped, or `{:error, reason}` where
  `reason` may be `:not_found` (key doesn't exist), `:empty_list` (list exists but is empty),
  or any of the standard error reasons.
  """
  @spec rpop(key :: key()) :: {:ok, value()} | {:error, list_error_reason()}
  def rpop(key) do
    do_list_operation_sync(key, :rpop)
  end

  @doc """
  Returns the length of the list stored at `key`.

  Returns `{:ok, length}` where `length` is a non-negative integer,
  or `{:error, reason}` where `reason` may be `:not_found` (key doesn't exist)
  or any of the standard error reasons.
  """
  @spec llen(key :: key()) :: {:ok, non_neg_integer()} | {:error, error_reason()}
  def llen(key) do
    do_list_operation_sync(key, :llen)
  end

  @doc """
  Returns the element at `index` in the list stored at `key`.

  The index is zero-based. Negative indices count from the end of the list
  (-1 is the last element, -2 is the second last, etc.).
  Returns `{:ok, value}` if the element exists, or `{:error, reason}` where
  `reason` may be `:not_found` (key doesn't exist), `:index_out_of_range`,
  or any of the standard error reasons.
  """
  @spec lindex(key :: key(), index :: integer()) :: {:ok, value()} | {:error, list_error_reason()}
  def lindex(key, index) when is_integer(index) do
    do_list_operation_sync(key, {:lindex, index})
  end

  @doc """
  Returns the specified elements of the list stored at `key`.

  The offsets `start` and `stop` are zero-based indices. Negative indices
  count from the end of the list. Both indices are inclusive.
  Returns `{:ok, values}` where `values` is a list of elements,
  or `{:error, reason}` where `reason` may be `:not_found` (key doesn't exist)
  or any of the standard error reasons.
  """
  @spec lrange(key :: key(), start :: integer(), stop :: integer()) ::
          {:ok, [value()]} | {:error, error_reason()}
  def lrange(key, start, stop) when is_integer(start) and is_integer(stop) do
    do_list_operation_sync(key, {:lrange, start, stop})
  end

  defp do_list_operation_sync(key, operation) do
    case find_shard_pid(key) do
      {:ok, pid} ->
        try do
          GenServer.call(pid, {operation, key})
        catch
          :exit, reason ->
            Logger.error(
              "Shard actor exited for key '#{inspect(key)}'. PID: #{inspect(pid)}, Reason: #{inspect(reason)}"
            )

            {:error, {:shard_crash, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec find_shard_pid(key :: key()) :: {:ok, pid()} | {:error, :shard_unavailable}
  defp find_shard_pid(key) do
    shard_id = Sharding.hash_key_to_shard(key, num_shards())
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
