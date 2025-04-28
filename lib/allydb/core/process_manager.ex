defmodule AllyDB.Core.ProcessManager do
  @moduledoc """
  Internal module for managing the lifecycle and registration of actor processes.

  Abstracts interactions with the Registry and DynamicSupervisor.
  """

  @typedoc "Unique identifier for a process."
  @type id :: any()

  @typedoc "Value of the registered process."
  @type value :: any()

  @doc """
  Starts a child process under the DynamicSupervisor.

  The `init_arg` provided here is passed directly to the child's `start_link/1` function.
  The child process itself is responsible for registration via `register_process/2`
  if needed, typically during its `init/1` callback.
  """
  @spec start_process(id :: id(), module :: module(), init_arg :: any()) ::
          DynamicSupervisor.on_start_child()
  def start_process(id, module, init_arg) do
    case lookup_process(id) do
      [{existing_pid, _value}] ->
        {:error, {:already_started, existing_pid}}

      [] ->
        child_id = {module, id}
        child_start_arg = init_arg

        child_spec = %{
          id: child_id,
          start: {module, :start_link, [child_start_arg]},
          restart: :transient
        }

        DynamicSupervisor.start_child(AllyDB.DynamicSupervisor, child_spec)
    end
  end

  @doc """
  Terminates a child process managed by the DynamicSupervisor.
  """
  @spec stop_process(id :: id()) :: :ok | {:error, :not_found}
  def stop_process(id) do
    case lookup_process(id) do
      [{pid, _value}] ->
        DynamicSupervisor.terminate_child(AllyDB.DynamicSupervisor, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Registers the given `pid` under the unique `id` in the Registry.
  """
  @spec register_process(id :: id(), pid :: pid()) ::
          {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register_process(id, pid) do
    Registry.register(AllyDB.Registry, id, pid)
  end

  @doc """
  Unregisters the given `id` from the Registry.
  """
  @spec unregister_process(id :: id()) :: :ok
  def unregister_process(id) do
    Registry.unregister(AllyDB.Registry, id)
  end

  @doc """
  Looks up the process registered under the given `id` in the Registry.
  """
  @spec lookup_process(id :: id()) :: [{pid(), value()}]
  def lookup_process(id) do
    Registry.lookup(AllyDB.Registry, id)
  end
end
