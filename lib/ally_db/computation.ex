defmodule AllyDB.Computation do
  @moduledoc """
  Defines the core behaviour for custom stateful actors within AllyDB.
  """

  @typedoc "The initialization argument passed to the actor when it starts."
  @type init_arg :: any()

  @typedoc "The internal state maintained by the actor."
  @type state :: any()

  @typedoc "The message received by the actor for synchronous processing."
  @type call_message :: any()

  @typedoc "The message received by the actor for asynchronous processing."
  @type cast_message :: any()

  @typedoc "An informational message received by the actor (e.g., monitor notifications)."
  @type info_message :: any()

  @typedoc "The reply sent back to the caller of a synchronous request."
  @type reply :: any()

  @typedoc """
  The reason for the actor terminating.
  """
  @type reason :: :normal | :shutdown | {:shutdown, term()} | term()

  @typedoc "Standard GenServer `from` type: `{pid(), tag :: term()}`."
  @type from :: GenServer.from()

  @doc """
  Invoked when the actor process is started.

  Receives the `init_arg` provided during actor startup.
  """
  @callback init(init_arg :: init_arg()) ::
              {:ok, state()} | {:stop, reason :: any()}

  @doc """
  Invoked to handle synchronous requests sent to the actor.

  Receives the `message`, the caller's reference `from` (allowing a reply),
  and the current actor `state`.
  """
  @callback handle_call(message :: call_message(), from :: from(), state :: state()) ::
              {:reply, reply :: reply(), new_state :: state()}
              | {:reply, reply :: reply(), new_state :: state(),
                 timeout() | :hibernate | {:continue, term()}}
              | {:noreply, new_state :: state()}
              | {:noreply, new_state :: state(), timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason :: reason(), reply :: reply(), new_state :: state()}
              | {:stop, reason :: reason(), new_state :: state()}

  @doc """
  Invoked to handle asynchronous requests sent to the actor

  Receives the `message` and the current actor `state`.
  """
  @callback handle_cast(message :: cast_message(), state :: state()) ::
              {:noreply, new_state :: state()}
              | {:noreply, new_state :: state(), timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason :: reason(), new_state :: state()}

  @doc """
  Invoked to handle all other messages received by the actor process that are
  not `call` or `cast` requests. This includes regular process messages, exit
  signals from linked processes, and node monitor notifications.

  Receives the `message` and the current actor `state`.
  """
  @callback handle_info(message :: info_message(), state :: state()) ::
              {:noreply, new_state :: state()}
              | {:noreply, new_state :: state(), timeout() | :hibernate | {:continue, term()}}
              | {:stop, reason :: reason(), new_state :: state()}

  @doc """
  Invoked when the actor process is about to terminate.

  It receives the `reason` for termination and the final actor `state`.

  The return value is ignored.
  """
  @callback terminate(reason :: reason(), state :: state()) :: any()
end
