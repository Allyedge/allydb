defmodule Allydb.IntervalPersistence do
  @moduledoc false

  use GenServer

  alias Allydb.Database

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(args) do
    args = Keyword.get(args, :args)

    Process.send_after(self(), :persist, List.last(args))

    {:ok,
     %{
       table: Allydb.Database,
       persistence_location: List.first(args),
       persistence_interval: List.last(args)
     }}
  end

  @impl true
  def handle_info(:persist, state) do
    case persist(state) do
      :ok -> {:noreply, state}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:load, state) do
    case load(state) do
      {:ok, state} -> {:noreply, state}
      {:error, reason} -> {:stop, reason, state}
    end
  end

  defp persist(state) do
    case :ets.tab2file(state.table, '#{state.persistence_location}') do
      :ok ->
        Process.send_after(self(), :persist, state.persistence_interval)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_from_file(state) do
    case :ets.file2tab('#{state.persistence_location}') do
      {:ok, _} ->
        Logger.info("LOAD -> #{state.persistence_location}")

        Process.send_after(self(), :persist, state.persistence_interval)

        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def load(state) do
    case File.exists?(state.persistence_location) do
      true -> load_from_file(state)
      false -> create_table(state)
    end
  end

  defp create_table(state) do
    case Database.create() do
      :ok ->
        Process.send_after(self(), :persist, state.persistence_interval)

        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def exists?(state) do
    File.exists?(state.persistence_location)
  end
end
