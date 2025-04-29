defmodule AllyDB.Example.Counter do
  @moduledoc """
  An example implementation of the `AllyDB.Computation` behaviour.

  This actor maintains a simple integer counter, which can be incremented,
  reset, and queried. It demonstrates how to implement the required callbacks,
  manage state, and register/unregister with the `ProcessManager`.
  """

  use GenServer
  require Logger

  alias AllyDB.Core.ProcessManager

  @typedoc "The unique identifier for this counter actor instance."
  @type actor_id :: String.t() | atom() | any()

  @typedoc "Initialization arguments: The unique ID for this actor."
  @type init_arg :: actor_id()

  @typedoc "The state of the Counter actor."
  @type state :: %{
          id: actor_id(),
          count: integer()
        }

  @typedoc "Possible request messages for `handle_call`."
  @type request :: any()

  @typedoc "Possible message messages for `handle_cast`."
  @type message :: any()

  @doc """
  Starts a Counter actor instance.
  """
  @spec start_link(init_arg :: init_arg()) :: GenServer.on_start()
  def start_link(actor_id) do
    GenServer.start_link(__MODULE__, actor_id, [])
  end

  @doc """
  Initializes the Counter actor state and registers the process.
  """
  @impl GenServer
  @spec init(init_arg :: init_arg()) ::
          {:ok, state()}
          | {:ok, state(), timeout() | :hibernate}
          | :ignore
          | {:stop, reason :: any()}
  def init(actor_id) do
    Logger.debug("Counter [#{inspect(actor_id)}]: Initializing.")
    initial_state = %{id: actor_id, count: 0}

    case ProcessManager.register_process(actor_id, self()) do
      {:ok, _pid} ->
        Logger.debug("Counter [#{inspect(actor_id)}]: Registered successfully.")

        {:ok, initial_state}

      {:error, {:already_registered, _pid}} = error ->
        Logger.error(
          "Counter [#{inspect(actor_id)}]: Failed to register, already exists. Error: #{inspect(error)}"
        )

        {:stop, {:registry_error, error}}
    end
  end

  @doc """
  Handles synchronous calls:
  - `:get`: Returns the current count.
  - `:increment`: Increments the count and returns the new count.
  """
  @impl GenServer
  @spec handle_call(request :: request(), from :: GenServer.from(), state :: state()) ::
          {:reply, reply :: any(), new_state :: state()}
          | {:reply, reply :: any(), new_state :: state(), timeout() | :hibernate}
          | {:noreply, new_state :: state()}
          | {:noreply, new_state :: state(), timeout() | :hibernate}
          | {:stop, reason :: any(), reply :: any(), new_state :: state()}
          | {:stop, reason :: any(), new_state :: state()}
  def handle_call(:get, _from, state = %{count: count, id: id}) do
    Logger.debug("Counter [#{inspect(id)}]: GET -> #{count}")
    {:reply, {:ok, count}, state}
  end

  def handle_call(:increment, _from, state = %{count: count, id: id}) do
    new_count = count + 1
    new_state = %{state | count: new_count}
    Logger.debug("Counter [#{inspect(id)}]: INCREMENT (sync) -> #{new_count}")
    {:reply, {:ok, new_count}, new_state}
  end

  def handle_call({:add, n}, _from, state = %{count: count, id: id}) when is_number(n) do
    new_count = count + n
    Logger.debug("Counter [#{inspect(id)}]: ADD (#{n}) (sync) -> #{new_count}")
    {:reply, {:ok, new_count}, %{state | count: new_count}}
  end

  def handle_call(request, _from, state = %{id: id}) do
    Logger.warning("Counter [#{inspect(id)}]: Received unexpected call: #{inspect(request)}")

    {:reply, {:error, :unknown_call}, state}
  end

  @doc """
  Handles asynchronous casts:
  - `:increment`: Increments the count.
  - `:reset`: Resets the count to 0.
  """
  @impl GenServer
  @spec handle_cast(message :: message(), state :: state()) ::
          {:noreply, new_state :: state()}
          | {:noreply, new_state :: state(), timeout() | :hibernate}
          | {:stop, reason :: any(), new_state :: state()}
  def handle_cast(:increment, state = %{count: count, id: id}) do
    new_count = count + 1
    new_state = %{state | count: new_count}
    Logger.debug("Counter [#{inspect(id)}]: INCREMENT (cast) -> #{new_count}")
    {:noreply, new_state}
  end

  def handle_cast(:reset, state = %{id: id}) do
    new_state = %{state | count: 0}
    Logger.debug("Counter [#{inspect(id)}]: RESET -> 0")
    {:noreply, new_state}
  end

  def handle_cast({:add, n}, state = %{count: count, id: id}) when is_number(n) do
    new_count = count + n
    new_state = %{state | count: new_count}
    Logger.debug("Counter [#{inspect(id)}]: ADD (#{n}) (cast) -> #{new_count}")
    {:noreply, new_state}
  end

  def handle_cast(message, state = %{id: id}) do
    Logger.warning("Counter [#{inspect(id)}]: Received unexpected cast: #{inspect(message)}")

    {:noreply, state}
  end

  @doc """
  Handles unexpected info messages.
  """
  @impl GenServer
  @spec handle_info(message :: any(), state :: state()) ::
          {:noreply, new_state :: state()}
          | {:noreply, new_state :: state(), timeout() | :hibernate}
          | {:stop, reason :: any(), new_state :: state()}
  def handle_info(message, state = %{id: id}) do
    Logger.warning("Counter [#{inspect(id)}]: Received unexpected info: #{inspect(message)}")

    {:noreply, state}
  end

  @doc """
  Cleans up by unregistering the process upon termination.
  """
  @impl GenServer
  @spec terminate(reason :: any(), state :: state()) :: :ok
  def terminate(reason, %{id: id}) do
    Logger.debug("Counter [#{inspect(id)}]: Terminating, reason: #{inspect(reason)}")

    ProcessManager.unregister_process(id)
    Logger.debug("Counter [#{inspect(id)}]: Unregistered.")
    :ok
  end
end
