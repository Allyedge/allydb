defmodule Allydb.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("ALLYDB_PORT") || "4000")

    persistence_location = System.get_env("ALLYDB_PERSISTENCE_LOCATION") || "allydb.tab"

    persistence_interval = String.to_integer(System.get_env("ALLYDB_PERSISTENCE_INTERVAL") || "10000")

    log_persistence_location = System.get_env("ALLYDB_LOG_PERSISTENCE_LOCATION") || "allydb.log"

    children = [
      {
        Allydb.Database,
        name: Allydb.Database
      },
      {
        Task.Supervisor,
        name: Allydb.Server.TaskSupervisor
      },
      Supervisor.child_spec({Task, fn -> Allydb.Server.accept(port) end}, restart: :permanent),
      {
        Allydb.Persistence,
        name: Allydb.Persistence, args: [log_persistence_location, persistence_location]
      },
      {
        Allydb.IntervalPersistence,
        name: Allydb.IntervalPersistence, args: [persistence_location, persistence_interval]
      }
    ]

    opts = [strategy: :one_for_one, name: Allydb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
