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

  @snapshot_dir Application.compile_env!(:allydb, [:persistence, :snapshot_dir])
  @snapshot_interval Application.compile_env!(:allydb, [:persistence, :snapshot_interval])

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

            Process.send_after(self(), :maybe_snapshot, @snapshot_interval)
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
            :private,
            read_concurrency: true,
            write_concurrency: true
          ])

        state = %{shard_id: shard_id, ets_tid: ets_tid, dirty: false}
        shard_process_id = "shard_#{shard_id}"

        case ProcessManager.register_process(shard_process_id, self()) do
          {:ok, _pid} ->
            Logger.debug("ShardActor [#{shard_id}]: Registered as '#{shard_process_id}'.")

            state = Map.put(state, :dirty, false)
            Process.send_after(self(), :maybe_snapshot, @snapshot_interval)
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
  Handles synchronous 'get' requests.
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
    if state.dirty do
      Logger.debug("ShardActor [#{state.shard_id}]: Snapshot.")

      save_snapshot(state)
      new_state = %{state | dirty: false}
      Process.send_after(self(), :maybe_snapshot, @snapshot_interval)
      {:noreply, new_state}
    end

    Process.send_after(self(), :maybe_snapshot, @snapshot_interval)
    {:noreply, state}
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
      :ets.new(table_name, [:set, :private, read_concurrency: true, write_concurrency: true])

    Enum.each(snapshot, fn {k, v} -> :ets.insert(ets_tid, {k, v}) end)
    %{shard_id: shard_id, ets_tid: ets_tid, dirty: false}
  end

  defp snapshot_path(id), do: Path.join(@snapshot_dir, "#{id}.snapshot")

  defp save_snapshot(state) do
    id = snapshot_id(state)
    File.mkdir_p!(@snapshot_dir)
    File.write!(snapshot_path(id), :erlang.term_to_binary(snapshot_state(state)))
  end

  defp load_snapshot(shard_id) do
    id = "shard_#{shard_id}"
    path = snapshot_path(id)

    if File.exists?(path) do
      {:ok, :erlang.binary_to_term(File.read!(path))}
    else
      :error
    end
  end
end
