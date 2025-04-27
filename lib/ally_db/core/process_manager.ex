defmodule AllyDB.Core.ProcessManager do
  @moduledoc """
  Internal module for managing the lifecycle and registration of actor processes.

  Abstracts interactions with the Registry and DynamicSupervisor.
  """

  @typedoc "Unique identifier for a process."
  @type id :: any()

  @doc """
  Starts a child process under the DynamicSupervisor.

  The `init_arg` provided here will be wrapped with the `id` into a tuple
  `{id, init_arg}` before being passed to the child's `start_link/1`.
  The child process itself is responsible for registration via `register_process/2`.
  """
  @spec start_process(id(), module(), init_arg :: any()) ::
          DynamicSupervisor.on_start_child()
  def start_process(id, module, init_arg) do
    child_id = {module, id}
    child_start_arg = {id, init_arg}

    child_spec = %{
      id: child_id,
      start: {module, :start_link, [child_start_arg]},
      restart: :transient
    }

    DynamicSupervisor.start_child(AllyDB.DynamicSupervisor, child_spec)
  end

  @doc """
  Terminates a child process managed by the DynamicSupervisor.
  """
  @spec stop_process(id()) :: :ok | {:error, :not_found}
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
  @spec register_process(id(), pid()) ::
          {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register_process(id, pid) do
    Registry.register(AllyDB.Registry, id, pid)
  end

  @doc """
  Unregisters the given `id` from the Registry.
  """
  @spec unregister_process(id()) :: :ok
  def unregister_process(id) do
    Registry.unregister(AllyDB.Registry, id)
  end

  @doc """
  Looks up the process registered under the given `id` in the Registry.
  """
  @spec lookup_process(id()) :: [{pid(), any()}]
  def lookup_process(id) do
    Registry.lookup(AllyDB.Registry, id)
  end
end
