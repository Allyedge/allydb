defmodule AllyDB.DynamicSupervisor do
  @moduledoc """
  Supervises the dynamically started actors (shards and custom actors).
  """

  use DynamicSupervisor

  @doc """
  Starts the DynamicSupervisor process. Called by the parent supervisor.
  """
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(__init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
