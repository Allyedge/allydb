defmodule AllyDB.DynamicSupervisor do
  @moduledoc """
  Supervises the dynamically started actors (shards and custom actors).
  """

  use DynamicSupervisor

  @doc """
  Starts the DynamicSupervisor process. Called by the parent supervisor.
  """
  @spec start_link(init_arg :: any()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  @spec init(_init_arg :: any()) :: {:ok, DynamicSupervisor.sup_flags()}
  def init(__init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
