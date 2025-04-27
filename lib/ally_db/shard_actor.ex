defmodule AllyDB.ShardActor do
  @moduledoc """
  A GenServer responsible for managing the data within a single database shard.

  Each ShardActor maintains a private ETS table holding key-value pairs
  belonging to its assigned shard. It handles internal messages for operations on that data.
  """

  use GenServer
  require Logger

  @typedoc "State of the ShardActor, holding shard ID and ETS table ID."
  @type state :: %{shard_id: non_neg_integer(), ets_tid: :ets.tab()}

  @typedoc "Initialization argument: {shard_id, options}."
  @type init_arg :: {non_neg_integer(), any()}

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
  @spec start_link(init_arg()) :: GenServer.on_start()
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, [])
  end

  @doc """
  Initializes the ShardActor process state when it starts.
  Creates the private ETS table for this shard.
  """
  @impl GenServer
  @spec init(init_arg()) :: {:ok, state()}
  def init({shard_id, _opts}) do
    Logger.debug("ShardActor [#{shard_id}]: Initializing.")

    table_name = :"shard_#{shard_id}_table"

    ets_tid =
      :ets.new(table_name, [:set, :private, read_concurrency: true, write_concurrency: true])

    state = %{shard_id: shard_id, ets_tid: ets_tid}
    {:ok, state}
  end

  @doc """
  Handles synchronous 'get' requests.
  Looks up the key in the shard's private ETS table.
  """
  @impl GenServer
  @spec handle_call(get_msg(), GenServer.from(), state()) ::
          {:reply, {:ok, any()}} | {:reply, {:error, :not_found}, state()}
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
  @spec handle_cast(set_msg(), state()) :: {:noreply, state()}
  @spec handle_cast(delete_msg(), state()) :: {:noreply, state()}
  def handle_cast({:set, key, value}, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    :ets.insert(ets_tid, {key, value})
    Logger.debug("ShardActor [#{shard_id}]: SET '#{inspect(key)}'")
    {:noreply, state}
  end

  def handle_cast({:delete, key}, state = %{ets_tid: ets_tid, shard_id: shard_id}) do
    :ets.delete(ets_tid, key)
    Logger.debug("ShardActor [#{shard_id}]: DELETE '#{inspect(key)}'")
    {:noreply, state}
  end

  @doc """
  Handles any unexpected messages sent to this process.
  """
  @impl GenServer
  def handle_info(message, state = %{shard_id: shard_id}) do
    Logger.warning("ShardActor [#{shard_id}]: Received unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  @doc """
  Cleans up resources when the ShardActor process terminates.
  Ensures the associated ETS table is deleted.
  """
  @impl GenServer
  def terminate(reason, _state = %{shard_id: shard_id, ets_tid: ets_tid}) do
    Logger.debug("ShardActor [#{shard_id}]: Terminating, reason: #{inspect(reason)}")
    :ets.delete(ets_tid)
    :ok
  end
end
