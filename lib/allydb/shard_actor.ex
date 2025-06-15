defmodule AllyDB.ShardActor do
  @moduledoc """
  A GenServer responsible for managing the data within a single database shard.

  Each ShardActor maintains a private ETS table holding key-value pairs
  belonging to its assigned shard. It handles internal messages for operations on that data.
  """

  alias AllyDB.Core.ProcessManager

  use GenServer
  @behaviour AllyDB.Snapshot

  require Logger

  @typedoc "Initialization argument: {shard_id, options}."
  @type init_arg :: {non_neg_integer(), any()}

  @typedoc "State of the ShardActor, holding shard ID and ETS table ID."
  @type state :: %{shard_id: non_neg_integer(), ets_tid: :ets.tab(), dirty: boolean()}

  @typedoc "The reason for the error."
  @type reason :: any()

  @typedoc "The value set for the key."
  @type value :: any()

  @typedoc "Internal message to get a value associated with a key."
  @type get_msg :: {:get, key :: any()}
  @typedoc "Internal message to set (or overwrite) a key-value pair."
  @type set_msg :: {:set, key :: any(), value :: any()}
  @typedoc "Internal message to delete a key and its associated value."
  @type delete_msg :: {:delete, key :: any()}

  @typedoc "Internal messages for list operations."
  @type lpush_msg :: {{:lpush, [any()]}, key :: any()}
  @type rpush_msg :: {{:rpush, [any()]}, key :: any()}
  @type lpop_msg :: {:lpop, key :: any()}
  @type rpop_msg :: {:rpop, key :: any()}
  @type llen_msg :: {:llen, key :: any()}
  @type lindex_msg :: {{:lindex, integer()}, key :: any()}
  @type lrange_msg :: {{:lrange, integer(), integer()}, key :: any()}

  @doc """
  Starts the ShardActor GenServer process.

  This function is called by the DynamicSupervisor when instructed by `AllyDB.Core.ProcessManager.start_process/3`.
  """
  @spec start_link(init_arg :: init_arg()) :: GenServer.on_start()
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, [])
  end

  @doc """
  Initializes the ShardActor process state when it starts.
  Creates the private ETS table for this shard.
  """
  @impl GenServer
  @spec init(init_arg :: init_arg()) :: {:ok, state()} | {:stop, {:registry_error, reason()}}
  def init({shard_id, _opts}) do
    Logger.debug("ShardActor [#{shard_id}]: Initializing.")

    case load_snapshot(shard_id) do
      {:ok, snapshot} ->
        state = restore_state(snapshot, shard_id)
        shard_process_id = "shard_#{shard_id}"
        Logger.debug("ShardActor [#{shard_id}]: Snapshot loaded.")

        case ProcessManager.register_process(shard_process_id, self()) do
          {:ok, _pid} ->
            Logger.debug("ShardActor [#{shard_id}]: Registered as '#{shard_process_id}'.")

            Process.send_after(self(), :maybe_snapshot, snapshot_interval())
            {:ok, state}

          {:error, reason} ->
            Logger.error(
              "ShardActor [#{shard_id}]: Failed to register process: #{inspect(reason)}"
            )

            {:stop, {:registry_error, reason}}
        end

      :error ->
        table_name = :"shard_#{shard_id}_table"

        ets_tid =
          :ets.new(table_name, [
            :set,
            :protected,
            read_concurrency: true,
            write_concurrency: true
          ])

        state = %{shard_id: shard_id, ets_tid: ets_tid, dirty: false}
        shard_process_id = "shard_#{shard_id}"

        case ProcessManager.register_process(shard_process_id, self()) do
          {:ok, _pid} ->
            Logger.debug("ShardActor [#{shard_id}]: Registered as '#{shard_process_id}'.")

            state = Map.put(state, :dirty, false)
            Process.send_after(self(), :maybe_snapshot, snapshot_interval())
            {:ok, state}

          {:error, reason} ->
            Logger.error(
              "ShardActor [#{shard_id}]: Failed to register process: #{inspect(reason)}"
            )

            {:stop, {:registry_error, reason}}
        end
    end
  end

  @doc """
  Handles synchronous 'get' requests and list operation requests.
  Looks up the key in the shard's private ETS table.
  """
  @impl GenServer
  @spec handle_call(message :: get_msg(), from :: GenServer.from(), state :: state()) ::
          {:reply, {:ok, value()}, state()} | {:reply, {:error, :not_found}, state()}
  def handle_call({:get, key}, _from, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    case :ets.lookup(ets_tid, key) do
      [{^key, value}] ->
        Logger.debug("ShardActor [#{shard_id}]: GET '#{inspect(key)}' -> Found")
        {:reply, {:ok, value}, state}

      [] ->
        Logger.debug("ShardActor [#{shard_id}]: GET '#{inspect(key)}' -> Not Found")
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({{:lpush, values}, key}, _from, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    current_list =
      case :ets.lookup(ets_tid, key) do
        [{^key, list}] when is_list(list) ->
          list

        [{^key, _other}] ->
          Logger.debug(
            "ShardActor [#{shard_id}]: LPUSH '#{inspect(key)}' -> Type mismatch, treating as empty list"
          )

          []

        [] ->
          []
      end

    new_list = Enum.reverse(values) ++ current_list
    :ets.insert(ets_tid, {key, new_list})
    new_length = length(new_list)
    Logger.debug("ShardActor [#{shard_id}]: LPUSH '#{inspect(key)}' -> New length: #{new_length}")
    new_state = %{state | dirty: true}
    {:reply, {:ok, new_length}, new_state}
  end

  def handle_call({{:rpush, values}, key}, _from, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    current_list =
      case :ets.lookup(ets_tid, key) do
        [{^key, list}] when is_list(list) ->
          list

        [{^key, _other}] ->
          Logger.debug(
            "ShardActor [#{shard_id}]: RPUSH '#{inspect(key)}' -> Type mismatch, treating as empty list"
          )

          []

        [] ->
          []
      end

    new_list = current_list ++ values
    :ets.insert(ets_tid, {key, new_list})
    new_length = length(new_list)
    Logger.debug("ShardActor [#{shard_id}]: RPUSH '#{inspect(key)}' -> New length: #{new_length}")
    new_state = %{state | dirty: true}
    {:reply, {:ok, new_length}, new_state}
  end

  def handle_call({:lpop, key}, _from, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    case :ets.lookup(ets_tid, key) do
      [{^key, [head | tail]}] ->
        :ets.insert(ets_tid, {key, tail})
        Logger.debug("ShardActor [#{shard_id}]: LPOP '#{inspect(key)}' -> Popped element")
        new_state = %{state | dirty: true}
        {:reply, {:ok, head}, new_state}

      [{^key, []}] ->
        Logger.debug("ShardActor [#{shard_id}]: LPOP '#{inspect(key)}' -> Empty list")
        {:reply, {:error, :empty_list}, state}

      [{^key, _other}] ->
        Logger.debug("ShardActor [#{shard_id}]: LPOP '#{inspect(key)}' -> Type mismatch")
        {:reply, {:error, :not_found}, state}

      [] ->
        Logger.debug("ShardActor [#{shard_id}]: LPOP '#{inspect(key)}' -> Not found")
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:rpop, key}, _from, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    case :ets.lookup(ets_tid, key) do
      [{^key, list}] when is_list(list) and length(list) > 0 ->
        {popped_element, new_list} = List.pop_at(list, -1)
        :ets.insert(ets_tid, {key, new_list})
        Logger.debug("ShardActor [#{shard_id}]: RPOP '#{inspect(key)}' -> Popped element")
        new_state = %{state | dirty: true}
        {:reply, {:ok, popped_element}, new_state}

      [{^key, []}] ->
        Logger.debug("ShardActor [#{shard_id}]: RPOP '#{inspect(key)}' -> Empty list")
        {:reply, {:error, :empty_list}, state}

      [{^key, _other}] ->
        Logger.debug("ShardActor [#{shard_id}]: RPOP '#{inspect(key)}' -> Type mismatch")
        {:reply, {:error, :not_found}, state}

      [] ->
        Logger.debug("ShardActor [#{shard_id}]: RPOP '#{inspect(key)}' -> Not found")
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:llen, key}, _from, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    case :ets.lookup(ets_tid, key) do
      [{^key, list}] when is_list(list) ->
        list_length = length(list)
        Logger.debug("ShardActor [#{shard_id}]: LLEN '#{inspect(key)}' -> Length: #{list_length}")
        {:reply, {:ok, list_length}, state}

      [{^key, _other}] ->
        Logger.debug("ShardActor [#{shard_id}]: LLEN '#{inspect(key)}' -> Type mismatch")
        {:reply, {:error, :not_found}, state}

      [] ->
        Logger.debug("ShardActor [#{shard_id}]: LLEN '#{inspect(key)}' -> Not found")
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({{:lindex, index}, key}, _from, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    case :ets.lookup(ets_tid, key) do
      [{^key, list}] when is_list(list) ->
        case safe_list_at(list, index) do
          {:ok, value} ->
            Logger.debug("ShardActor [#{shard_id}]: LINDEX '#{inspect(key)}' [#{index}] -> Found")
            {:reply, {:ok, value}, state}

          :error ->
            Logger.debug(
              "ShardActor [#{shard_id}]: LINDEX '#{inspect(key)}' [#{index}] -> Index out of range"
            )

            {:reply, {:error, :index_out_of_range}, state}
        end

      [{^key, _other}] ->
        Logger.debug("ShardActor [#{shard_id}]: LINDEX '#{inspect(key)}' -> Type mismatch")
        {:reply, {:error, :not_found}, state}

      [] ->
        Logger.debug("ShardActor [#{shard_id}]: LINDEX '#{inspect(key)}' -> Not found")
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(
        {{:lrange, start, stop}, key},
        _from,
        state = %{ets_tid: ets_tid, shard_id: shard_id}
      ) do
    case :ets.lookup(ets_tid, key) do
      [{^key, list}] when is_list(list) ->
        result = safe_list_slice(list, start, stop)

        Logger.debug(
          "ShardActor [#{shard_id}]: LRANGE '#{inspect(key)}' [#{start}:#{stop}] -> #{length(result)} elements"
        )

        {:reply, {:ok, result}, state}

      [{^key, _other}] ->
        Logger.debug("ShardActor [#{shard_id}]: LRANGE '#{inspect(key)}' -> Type mismatch")
        {:reply, {:error, :not_found}, state}

      [] ->
        Logger.debug("ShardActor [#{shard_id}]: LRANGE '#{inspect(key)}' -> Not found")
        {:reply, {:error, :not_found}, state}
    end
  end

  @doc """
  Handles asynchronous 'set' and 'delete' requests.

  - `{:set, key, value}`: Inserts or updates the key-value pair in the ETS table.
  - `{:delete, key}`: Removes the key-value pair from the ETS table.
  """
  @impl GenServer
  @spec handle_cast(message :: set_msg(), state :: state()) :: {:noreply, state()}
  @spec handle_cast(message :: delete_msg(), state :: state()) :: {:noreply, state()}
  def handle_cast({:set, key, value}, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    :ets.insert(ets_tid, {key, value})
    Logger.debug("ShardActor [#{shard_id}]: SET '#{inspect(key)}'")
    new_state = %{state | dirty: true}
    {:noreply, new_state}
  end

  def handle_cast({:delete, key}, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    :ets.delete(ets_tid, key)
    Logger.debug("ShardActor [#{shard_id}]: DELETE '#{inspect(key)}'")
    new_state = %{state | dirty: true}
    {:noreply, new_state}
  end

  @doc """
  Handles any unexpected messages sent to this process.
  """
  @impl GenServer
  @spec handle_info(message :: any(), state :: state()) :: {:noreply, state()}
  def handle_info(:maybe_snapshot, state) do
    # Only run snapshot logic if state is dirty, then schedule next tick once
    new_state =
      if state.dirty do
        Logger.debug("ShardActor [#{state.shard_id}]: Snapshot.")
        save_snapshot(state)
        %{state | dirty: false}
      else
        state
      end

    Process.send_after(self(), :maybe_snapshot, snapshot_interval())
    {:noreply, new_state}
  end

  def handle_info(message, state = %{shard_id: shard_id}) do
    Logger.warning("ShardActor [#{shard_id}]: Received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  @doc """
  Cleans up resources when the ShardActor process terminates.
  Ensures the associated ETS table is deleted.
  """
  @impl GenServer
  @spec terminate(reason :: reason(), state :: state()) :: :ok
  def terminate(reason, _state = %{shard_id: shard_id, ets_tid: ets_tid}) do
    Logger.debug("ShardActor [#{shard_id}]: Terminating, reason: #{inspect(reason)}")
    shard_process_id = "shard_#{shard_id}"
    ProcessManager.unregister_process(shard_process_id)
    Logger.debug("ShardActor [#{shard_id}]: Unregistered.")

    if is_reference(ets_tid) and :ets.info(ets_tid) != :undefined do
      :ets.delete(ets_tid)
    else
      Logger.debug("ShardActor [#{shard_id}]: ETS table already deleted.")
    end

    :ok
  end

  @impl AllyDB.Snapshot
  def snapshot_id(%{shard_id: shard_id}), do: "shard_#{shard_id}"

  @impl AllyDB.Snapshot
  def snapshot_state(%{ets_tid: ets_tid}) do
    :ets.tab2list(ets_tid)
  end

  @impl AllyDB.Snapshot
  def restore_state(snapshot, shard_id) do
    table_name = :"shard_#{shard_id}_table"

    ets_tid =
      :ets.new(table_name, [:set, :protected, read_concurrency: true, write_concurrency: true])

    Enum.each(snapshot, fn {k, v} -> :ets.insert(ets_tid, {k, v}) end)
    %{shard_id: shard_id, ets_tid: ets_tid, dirty: false}
  end

  defp safe_list_at(list, index) do
    normalized_index = normalize_index(index, length(list))

    if normalized_index >= 0 and normalized_index < length(list) do
      {:ok, Enum.at(list, normalized_index)}
    else
      :error
    end
  end

  defp safe_list_slice(list, start, stop) do
    list_length = length(list)

    cond do
      list_length == 0 ->
        []

      out_of_bounds?(start, stop, list_length) ->
        []

      true ->
        extract_slice(list, start, stop, list_length)
    end
  end

  defp out_of_bounds?(start, stop, list_length) do
    normalized_start = normalize_index(start, list_length)
    normalized_stop = normalize_index(stop, list_length)

    normalized_start >= list_length or normalized_stop < 0 or normalized_start > normalized_stop
  end

  defp extract_slice(list, start, stop, list_length) do
    normalized_start = normalize_index(start, list_length)
    normalized_stop = normalize_index(stop, list_length)

    start_idx = max(0, normalized_start)
    stop_idx = min(normalized_stop, list_length - 1)

    if start_idx <= stop_idx do
      list
      |> Enum.with_index()
      |> Enum.filter(fn {_elem, idx} -> idx >= start_idx and idx <= stop_idx end)
      |> Enum.map(fn {elem, _idx} -> elem end)
    else
      []
    end
  end

  defp normalize_index(index, list_length) when index < 0 do
    list_length + index
  end

  defp normalize_index(index, _list_length) do
    index
  end

  defp snapshot_path(id), do: Path.join(snapshot_dir(), "#{id}.snapshot")

  defp save_snapshot(state) do
    id = snapshot_id(state)
    data = snapshot_state(state)

    Task.Supervisor.start_child(AllyDB.SnapshotTaskSupervisor, fn ->
      try do
        File.mkdir_p!(snapshot_dir())
        tmp_path = snapshot_path(id) <> ".tmp"
        File.write!(tmp_path, :erlang.term_to_binary(data))
        File.rename!(tmp_path, snapshot_path(id))
      rescue
        e -> Logger.error("ShardActor [#{id}]: Failed to write snapshot: #{inspect(e)}")
      end
    end)
  end

  defp load_snapshot(shard_id) do
    id = "shard_#{shard_id}"
    path = snapshot_path(id)

    if File.exists?(path) do
      try do
        {:ok, :erlang.binary_to_term(File.read!(path))}
      rescue
        e ->
          Logger.error(
            "ShardActor [#{shard_id}]: Failed to load snapshot from #{path}: #{inspect(e)}"
          )

          :error
      end
    else
      :error
    end
  end

  defp snapshot_dir, do: Application.get_env(:allydb, :persistence)[:snapshot_dir]
  defp snapshot_interval, do: Application.get_env(:allydb, :persistence)[:snapshot_interval]
end
