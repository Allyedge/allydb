defmodule AllyDB.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      %{
        id: AllyDB.Registry,
        start: {Registry, :start_link, [[keys: :unique, name: AllyDB.Registry]]}
      },
      AllyDB.DynamicSupervisor,
      AllyDB.ShardInitializer
    ]

    opts = [strategy: :one_for_one, name: AllyDB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
