defmodule Allydb.Persistence do
  @moduledoc false

  use GenServer

  alias Allydb.Database
  alias Allydb.Handlers
  alias Allydb.IntervalPersistence
  alias Allydb.Utils

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    args = Keyword.get(args, :args)

    Process.send_after(self(), :load, 0)

    {:ok,
     %{
       log_persistence_location: List.first(args),
       persistance_location: List.last(args),
       file: File.open!(List.first(args), [:append])
     }}
  end

  @impl true
  def handle_info(:load, state) do
    create_table(state)

    load(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:persist, line}, state) do
    persist_to_file(state, line)

    {:noreply, state}
  end

  def persist(line) do
    GenServer.cast(__MODULE__, {:persist, line})
  end

  defp persist_to_file(state, line) do
    if line == " " do
      :ok
    else
      IO.write(state.file, "#{line}\n")
    end
  end

  defp load(state) do
    case File.exists?(state.log_persistence_location) do
      true ->
        state.log_persistence_location
        |> File.stream!()
        |> Stream.map(&handle/1)
        |> Stream.run()

        {:ok, state}

      false ->
        case IntervalPersistence.exists?(state.persistance_location) do
          true ->
            IntervalPersistence.load(state.persistance_location)

          false ->
            :ok
        end

        File.touch!(state.log_persistence_location)

        {:ok, state}
    end
  end

  defp create_table(state) do
    case Database.create() do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle(line) do
    line |> Utils.parse_line_with_end() |> Handlers.handle_line()
  end
end
