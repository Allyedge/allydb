defmodule AllyDB.Snapshot do
  @moduledoc """
  Behaviour for actors that support snapshotting (state persistence).
  """

  @callback snapshot_id(state :: any()) :: String.t()
  @callback snapshot_state(state :: any()) :: any()
  @callback restore_state(snapshot :: any(), init_arg :: any()) :: any()
end
