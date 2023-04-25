defmodule Allydb.Database do
  @moduledoc false
  alias Allydb.Utils

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, __MODULE__}
  end

  @impl true
  def handle_cast({:set, key, value}, state) do
    :ets.insert(state, {key, value})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete, key}, state) do
    :ets.delete(state, key)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:lpush, key, value}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] -> :ets.insert(state, {key, [value | list]})
      [] -> :ets.insert(state, {key, [value]})
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:lpushx, key, value}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        :ets.insert(state, {key, [value | list]})

        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:rpush, key, value}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] -> :ets.insert(state, {key, list ++ [value]})
      [] -> :ets.insert(state, {key, [value]})
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:rpushx, key, value}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        :ets.insert(state, {key, list ++ [value]})

        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:ltrim, key, start, stop}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        :ets.insert(state, {key, Enum.slice(list, start, stop - start + 1)})

        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:lrem, key, value}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        filtered = Enum.filter(list, &(&1 != value))

        :ets.insert(state, {key, filtered})

        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:linsert, key, position, pivot, value}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        index = Enum.find_index(list, &(&1 == pivot))

        case index do
          nil ->
            {:noreply, state}

          _ ->
            case position do
              :before ->
                :ets.insert(
                  state,
                  {key, Enum.take(list, index) ++ value ++ Enum.drop(list, index)}
                )

              :after ->
                :ets.insert(
                  state,
                  {key, Enum.take(list, index + 1) ++ [value] ++ Enum.drop(list, index + 1)}
                )
            end

            {:noreply, state}
        end

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:lset, key, index, value}, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        :ets.insert(state, {key, Enum.take(list, index) ++ [value] ++ Enum.drop(list, index + 1)})

        {:noreply, state}

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:hset, key, value}, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} ->
            new_map = Map.merge(map, value)

            :ets.insert(state, {key, new_map})

            {:noreply, state}

          _ ->
            :ets.insert(state, {key, value})

            {:noreply, state}
        end

      [] ->
        :ets.insert(state, {key, value})

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:hdel, key, fields}, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} ->
            filtered = Enum.filter(fields, &Map.has_key?(map, &1))

            :ets.insert(state, {key, Map.drop(map, filtered)})

            {:noreply, state}

          _ ->
            {:noreply, state}
        end

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:sadd, key, values}, state) do
    case :ets.lookup(state, key) do
      [{_, set}] ->
        case set do
          %MapSet{} ->
            new_set = MapSet.union(set, MapSet.new(values))

            :ets.insert(state, {key, new_set})

            {:noreply, state}

          _ ->
            :ets.insert(state, {key, MapSet.new(values)})

            {:noreply, state}
        end

      [] ->
        :ets.insert(state, {key, MapSet.new(values)})

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:srem, key, values}, state) do
    case :ets.lookup(state, key) do
      [{_, set}] ->
        case set do
          %MapSet{} ->
            new_set = MapSet.difference(set, MapSet.new(values))

            :ets.insert(state, {key, new_set})

            {:noreply, state}

          _ ->
            {:noreply, state}
        end

      [] ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:create, _from, state) do
    :ets.new(state, [:named_table, :public, :set])

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, value}] ->
        case value do
          %MapSet{} ->
            list = MapSet.to_list(value)

            text = Utils.list_to_string(list)

            {:reply, text, state}

          _ ->
            {:reply, value, state}
        end

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:exists, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, _}] ->
        {:reply, 1, state}

      [] ->
        {:reply, 0, state}
    end
  end

  @impl true
  def handle_call({:lpop, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, [value | list]}] ->
        :ets.insert(state, {key, list})

        {:reply, value, state}

      [{_, []}] ->
        {:reply, nil, state}

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:rpop, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        value = Enum.at(list, -1)

        :ets.insert(state, {key, Enum.take(list, length(list) - 1)})

        {:reply, value, state}

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:llen, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, list}] -> {:reply, length(list), state}
      [] -> {:reply, 0, state}
    end
  end

  @impl true
  def handle_call({:lindex, key, index}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        {:reply, Enum.at(list, index), state}

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:lrange, key, start, stop}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        if stop < 0 do
          {:reply, list, state}
        else
          if start < length(list) and stop < length(list) do
            {:reply, Enum.slice(list, start, stop - start + 1), state}
          else
            {:reply, [], state}
          end
        end

      [] ->
        {:reply, [], state}
    end
  end

  @impl true
  def handle_call({:lpos, key, value}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, list}] ->
        {:reply, Enum.find_index(list, &(&1 == value)), state}

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:hget, key, field}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} -> {:reply, Map.get(map, field), state}
          _ -> {:reply, nil, state}
        end

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:hgetall, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} -> {:reply, map, state}
          _ -> {:reply, nil, state}
        end

      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:hlen, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} -> {:reply, Kernel.map_size(map), state}
          _ -> {:reply, 0, state}
        end

      [] ->
        {:reply, 0, state}
    end
  end

  @impl true
  def handle_call({:hexists, key, field}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} ->
            has_key =
              case Map.has_key?(map, field) do
                true -> 1
                false -> 0
              end

            {:reply, has_key, state}

          _ ->
            {:reply, 0, state}
        end

      [] ->
        {:reply, 1, state}
    end
  end

  @impl true
  def handle_call({:hkeys, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} -> {:reply, Map.keys(map), state}
          _ -> {:reply, [], state}
        end

      [] ->
        {:reply, [], state}
    end
  end

  @impl true
  def handle_call({:hvals, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, map}] ->
        case map do
          %{} -> {:reply, Map.values(map), state}
          _ -> {:reply, [], state}
        end

      [] ->
        {:reply, [], state}
    end
  end

  @impl true
  def handle_call({:smembers, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, set}] ->
        case set do
          %MapSet{} -> {:reply, MapSet.to_list(set), state}
          _ -> {:reply, [], state}
        end

      [] ->
        {:reply, [], state}
    end
  end

  @impl true
  def handle_call({:scard, key}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, set}] ->
        case set do
          %MapSet{} -> {:reply, MapSet.size(set), state}
          _ -> {:reply, 0, state}
        end

      [] ->
        {:reply, 0, state}
    end
  end

  @impl true
  def handle_call({:sdiff, keys}, _from, state) do
    diff =
      Enum.reduce(keys, nil, fn key, acc ->
        case :ets.lookup(state, key) do
          [{_, set}] ->
            case set do
              %MapSet{} ->
                if is_nil(acc) do
                  set
                else
                  MapSet.difference(acc, set)
                end

              _ ->
                acc
            end

          [] ->
            acc
        end
      end)

    {:reply, MapSet.to_list(diff), state}
  end

  @impl true
  def handle_call({:sinter, keys}, _from, state) do
    inter =
      Enum.reduce(keys, nil, fn key, acc ->
        case :ets.lookup(state, key) do
          [{_, set}] ->
            case set do
              %MapSet{} ->
                if is_nil(acc) do
                  set
                else
                  MapSet.intersection(acc, set)
                end

              _ ->
                acc
            end

          [] ->
            acc
        end
      end)

    {:reply, MapSet.to_list(inter), state}
  end

  @impl true
  def handle_call({:sismember, key, value}, _from, state) do
    case :ets.lookup(state, key) do
      [{_, set}] ->
        case set do
          %MapSet{} ->
            is_member =
              case MapSet.member?(set, value) do
                true -> 1
                false -> 0
              end

            {:reply, is_member, state}

          _ ->
            {:reply, 0, state}
        end

      [] ->
        {:reply, 0, state}
    end
  end

  @impl true
  def handle_call({:sunion, keys}, _from, state) do
    union =
      Enum.reduce(keys, nil, fn key, acc ->
        case :ets.lookup(state, key) do
          [{_, set}] ->
            case set do
              %MapSet{} ->
                if is_nil(acc) do
                  set
                else
                  MapSet.union(acc, set)
                end

              _ ->
                acc
            end

          [] ->
            acc
        end
      end)

    {:reply, MapSet.to_list(union), state}
  end

  def create() do
    GenServer.call(__MODULE__, :create)
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def set(key, value) do
    GenServer.cast(__MODULE__, {:set, key, value})
  end

  def exists(key) do
    GenServer.call(__MODULE__, {:exists, key})
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  def lpush(key, value) do
    GenServer.cast(__MODULE__, {:lpush, key, value})
  end

  def lpushx(key, value) do
    GenServer.cast(__MODULE__, {:lpushx, key, value})
  end

  def rpush(key, value) do
    GenServer.cast(__MODULE__, {:rpush, key, value})
  end

  def rpushx(key, value) do
    GenServer.cast(__MODULE__, {:rpushx, key, value})
  end

  def lpop(key) do
    GenServer.call(__MODULE__, {:lpop, key})
  end

  def rpop(key) do
    GenServer.call(__MODULE__, {:rpop, key})
  end

  def llen(key) do
    GenServer.call(__MODULE__, {:llen, key})
  end

  def ltrim(key, start, stop) do
    GenServer.call(__MODULE__, {:ltrim, key, start, stop})
  end

  def lindex(key, index) do
    GenServer.call(__MODULE__, {:lindex, key, index})
  end

  def lrange(key, start, stop) do
    GenServer.call(__MODULE__, {:lrange, key, start, stop})
  end

  def lpos(key, value) do
    GenServer.call(__MODULE__, {:lpos, key, value})
  end

  def lrem(key, value) do
    GenServer.cast(__MODULE__, {:lrem, key, value})
  end

  def linsert(key, position, pivot, value) do
    GenServer.cast(__MODULE__, {:linsert, key, position, pivot, value})
  end

  def lset(key, index, value) do
    GenServer.cast(__MODULE__, {:lset, key, index, value})
  end

  def hset(key, value) do
    GenServer.cast(__MODULE__, {:hset, key, value})
  end

  def hget(key, field) do
    GenServer.call(__MODULE__, {:hget, key, field})
  end

  def hgetall(key) do
    GenServer.call(__MODULE__, {:hgetall, key})
  end

  def hdel(key, field) do
    GenServer.cast(__MODULE__, {:hdel, key, field})
  end

  def hlen(key) do
    GenServer.call(__MODULE__, {:hlen, key})
  end

  def hexists(key, field) do
    GenServer.call(__MODULE__, {:hexists, key, field})
  end

  def hkeys(key) do
    GenServer.call(__MODULE__, {:hkeys, key})
  end

  def hvals(key) do
    GenServer.call(__MODULE__, {:hvals, key})
  end

  def sadd(key, value) do
    GenServer.cast(__MODULE__, {:sadd, key, value})
  end

  def smembers(key) do
    GenServer.call(__MODULE__, {:smembers, key})
  end

  def srem(key, value) do
    GenServer.cast(__MODULE__, {:srem, key, value})
  end

  def scard(key) do
    GenServer.call(__MODULE__, {:scard, key})
  end

  def sdiff(keys) do
    GenServer.call(__MODULE__, {:sdiff, keys})
  end

  def sinter(keys) do
    GenServer.call(__MODULE__, {:sinter, keys})
  end

  def sismember(key, value) do
    GenServer.call(__MODULE__, {:sismember, key, value})
  end

  def sunion(keys) do
    GenServer.call(__MODULE__, {:sunion, keys})
  end
end
