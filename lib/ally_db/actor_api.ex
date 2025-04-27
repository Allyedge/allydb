defmodule AllyDB.ActorAPI do
  @moduledoc """
  Provides the internal API for managing and interacting with custom actors.

  This module handles starting, stopping, and communicating (call/cast) with custom
  actor processes (typically `GenServer`s), using the underlying `AllyDB.Core.ProcessManager`
  """

  alias AllyDB.Core.ProcessManager

  require Logger

  @typedoc "The unique identifier for an actor instance."
  @type actor_id :: ProcessManager.id()

  @typedoc "The module implementing the `AllyDB.Computation` behaviour."
  @type actor_module :: module()

  @typedoc "Initialization arguments passed to the actor's `init/1` callback."
  @type init_arg :: any()

  @typedoc "The request message sent via `call/3`."
  @type request :: any()

  @typedoc "The message sent via `cast/2`."
  @type message :: any()

  @typedoc "The reply received from a `call/3`."
  @type reply :: any()

  @typedoc "Possible error reasons returned by API functions."
  @type error_reason ::
          :actor_not_found
          | {:start_failed, any()}
          | {:actor_crash, any()}
          | {:call_timeout}

  @default_call_timeout 5000

  @doc """
  Starts a new actor process instance.

  The actor identified by `actor_module` (which should be an OTP process, typically a `GenServer`)
  will be started under the `AllyDB.DynamicSupervisor`. The `actor_id` must be
  unique for registration. The `init_arg` is passed to the actor's `start_link/1`.

  The actor itself is responsible for registering its `actor_id` via
  `ProcessManager.register_process/2` during its initialization.
  """
  @spec start_actor(
          actor_id :: actor_id(),
          actor_module :: actor_module(),
          init_arg :: init_arg()
        ) ::
          {:ok, pid()}
          | {:error, {:already_started, pid()}}
          | {:error, {:start_failed, any()}}
  def start_actor(actor_id, actor_module, init_arg) do
    if not Code.ensure_loaded?(actor_module) or
         not function_exported?(actor_module, :behaviour_info, 1) or
         :computation not in actor_module.behaviour_info(:callbacks) do
      {:error, {:start_failed, :invalid_module}}
    end

    case ProcessManager.start_process(actor_id, actor_module, init_arg) do
      {:ok, pid} ->
        Logger.info(
          "ActorAPI: Started actor '#{inspect(actor_id)}' (Module: #{inspect(actor_module)}, PID: #{inspect(pid)})"
        )

        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.warning(
          "ActorAPI: Actor '#{inspect(actor_id)}' already started (PID: #{inspect(pid)})"
        )

        {:error, {:already_started, pid}}

      {:error, reason} ->
        Logger.error(
          "ActorAPI: Failed to start actor '#{inspect(actor_id)}' (Module: #{inspect(actor_module)}). Reason: #{inspect(reason)}"
        )

        {:error, {:start_failed, reason}}
    end
  end

  @doc """
  Stops a running actor process instance identified by `actor_id`.
  """
  @spec stop_actor(actor_id :: actor_id()) :: :ok | {:error, :actor_not_found}
  def stop_actor(actor_id) do
    case ProcessManager.stop_process(actor_id) do
      :ok ->
        Logger.info("ActorAPI: Stopped actor '#{inspect(actor_id)}'")
        :ok

      {:error, :not_found} ->
        Logger.error("ActorAPI: Failed to stop actor '#{inspect(actor_id)}'. Reason: Not found.")

        {:error, :actor_not_found}
    end
  end

  @doc """
  Sends a synchronous request to the actor identified by `actor_id`.

  Waits for a reply from the actor's `handle_call/3` callback.
  Returns `{:ok, reply}` where `reply` is the actual value returned by the
  actor's `handle_call/3` (e.g., `{:ok, value}` or `{:error, reason}`).
  Returns `{:error, :actor_not_found}` if the actor ID is not registered.
  Returns `{:error, :call_timeout}` if the actor doesn't reply within the timeout.
  Returns `{:error, {:actor_crash, reason}}` if the actor process crashes during the call.
  """
  @spec call(
          actor_id :: actor_id(),
          request :: request(),
          timeout :: timeout()
        ) ::
          {:ok, reply()} | {:error, error_reason()}
  def call(actor_id, request, timeout \\ @default_call_timeout) do
    case find_actor_pid(actor_id) do
      {:ok, pid} ->
        try do
          GenServer.call(pid, request, timeout)
        catch
          :exit, {:timeout, {GenServer, :call, [_, _, ^timeout]}} ->
            Logger.error(
              "ActorAPI: Call to actor '#{inspect(actor_id)}' timed out after #{timeout}ms."
            )

            {:error, :call_timeout}

          :exit, reason ->
            Logger.error(
              "ActorAPI: Call to actor '#{inspect(actor_id)}' (PID: #{inspect(pid)}) crashed. Reason: #{inspect(reason)}"
            )

            {:error, {:actor_crash, reason}}
        else
          reply ->
            {:ok, reply}
        end

      {:error, :actor_not_found} ->
        {:error, :actor_not_found}
    end
  end

  @doc """
  Sends an asynchronous message to the actor identified by `actor_id`.

  Does not wait for a reply. The message is handled by the actor's `handle_cast/2`.
  Returns `:ok` if the actor ID was found (message sent).
  Returns `{:error, :actor_not_found}` if the actor ID is not registered.
  """
  @spec cast(actor_id :: actor_id(), message :: message()) ::
          :ok | {:error, :actor_not_found}
  def cast(actor_id, message) do
    case find_actor_pid(actor_id) do
      {:ok, pid} ->
        GenServer.cast(pid, message)
        :ok

      {:error, :actor_not_found} ->
        {:error, :actor_not_found}
    end
  end

  @spec find_actor_pid(actor_id :: actor_id()) ::
          {:ok, pid()} | {:error, :actor_not_found}
  defp find_actor_pid(actor_id) do
    case ProcessManager.lookup_process(actor_id) do
      [{pid, _value}] ->
        {:ok, pid}

      [] ->
        Logger.error("ActorAPI: Cannot find PID for actor '#{inspect(actor_id)}'.")

        {:error, :actor_not_found}
    end
  end
end
