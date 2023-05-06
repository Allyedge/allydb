defmodule Allydb.Handlers do
  @moduledoc false

  alias Allydb.Database
  alias Allydb.Utils

  require Logger

  @new_line "\n"

  def handle_line(command, socket \\ nil)

  def handle_line([""], socket) do
    send_empty_response(socket)

    " "
  end

  def handle_line(["PING"], socket) do
    send_response(socket, "PONG")

    " "
  end

  def handle_line(["GET", key], socket) do
    value = Database.get(key)

    Logger.info("GET #{key} -> #{value}")

    send_response(socket, value)

    " "
  end

  def handle_line(["SET", key | values], socket) do
    value = Utils.list_to_string(values)

    Database.set(key, value)

    Logger.info("SET #{key} -> #{value}")

    send_response(socket, value)

    "SET #{key} #{value}"
  end

  def handle_line(["SETNX", key | values], socket) do
    value = Utils.list_to_string(values)

    response = Database.setnx(key, value)

    Logger.info("SETNX #{key} -> #{value}")

    send_response(socket, response)

    case response do
      1 -> "SETNX #{key} #{value}"
      0 -> " "
    end
  end

  def handle_line(["DEL", key], socket) do
    Database.delete(key)

    Logger.info("DEL #{key}")

    send_response(socket, key)

    "DEL #{key}"
  end

  def handle_line(["LPUSH", key | values], socket) do
    value = Utils.list_to_string(values)

    Database.lpush(key, value)

    Logger.info("LPUSH #{key} -> #{value}")

    send_response(socket, value)

    "LPUSH #{key} #{value}"
  end

  def handle_line(["LPUSHX", key | values], socket) do
    value = Utils.list_to_string(values)

    Database.lpushx(key, value)

    Logger.info("LPUSHX #{key} -> #{value}")

    send_response(socket, value)

    "LPUSHX #{key} #{value}"
  end

  def handle_line(["RPUSH", key | values], socket) do
    value = Utils.list_to_string(values)

    Database.rpush(key, value)

    Logger.info("RPUSH #{key} -> #{value}")

    send_response(socket, value)

    "RPUSH #{key} #{value}"
  end

  def handle_line(["RPUSHX", key | values], socket) do
    value = Utils.list_to_string(values)

    Database.rpushx(key, value)

    Logger.info("RPUSHX #{key} -> #{value}")

    send_response(socket, value)

    "RPUSHX #{key} #{value}"
  end

  def handle_line(["LPOP", key], socket) do
    value = Database.lpop(key)

    Logger.info("LPOP #{key} -> #{value}")

    send_response(socket, value)

    "LPOP #{key}"
  end

  def handle_line(["RPOP", key], socket) do
    value = Database.rpop(key)

    Logger.info("RPOP #{key} -> #{value}")

    send_response(socket, value)

    "RPOP #{key}"
  end

  def handle_line(["LLEN", key], socket) do
    value = Database.llen(key)

    Logger.info("LLEN #{key} -> #{value}")

    send_response(socket, value)

    " "
  end

  def handle_line(["LTRIM", key, start, stop], socket) do
    start = String.to_integer(start)
    stop = String.to_integer(stop)

    Database.ltrim(key, start, stop)

    Logger.info("LTRIM #{key} -> #{start} #{stop}")

    send_response(socket, "ok")

    "LTRIM #{key} #{start} #{stop}"
  end

  def handle_line(["LINDEX", key, index], socket) do
    index = String.to_integer(index)

    value = Database.lindex(key, index)

    Logger.info("LINDEX #{key} -> #{value}")

    send_response(socket, value)

    " "
  end

  def handle_line(["LRANGE", key, start, stop], socket) do
    start = String.to_integer(start)
    stop = String.to_integer(stop)

    value = Database.lrange(key, start, stop)

    Logger.info("LRANGE #{key} -> #{value}")

    Enum.each(value, fn x ->
      send_line_response(socket, x)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["LPOS", key, value], socket) do
    index = Database.lpos(key, value)

    Logger.info("LPOS #{key} -> #{index}")

    send_response(socket, index)

    " "
  end

  def handle_line(["LREM", key, value], socket) do
    Database.lrem(key, value)

    Logger.info("LREM #{key}")

    send_response(socket, key)

    "LREM #{key} #{value}"
  end

  def handle_line(["LINSERT", key, before_after, pivot | value], socket) do
    case String.downcase(before_after) do
      "before" ->
        Database.linsert(key, :before, pivot, value)

        Logger.info("LINSERT #{key}")

        send_response(socket, key)

        "LINSERT #{key} #{before_after} #{pivot} #{value}"

      "after" ->
        Database.linsert(key, :after, pivot, value)

        Logger.info("LINSERT #{key}")

        send_response(socket, key)

        "LINSERT #{key} #{before_after} #{pivot} #{value}"

      _ ->
        Logger.info("LINSERT #{key} -> Invalid before_after: #{before_after}")

        send_response(socket, "Invalid command: LINSERT #{key} #{before_after} #{pivot} #{value}")

        " "
    end
  end

  def handle_line(["LSET", key, index, value], socket) do
    index = String.to_integer(index)

    Database.lset(key, index, value)

    Logger.info("LSET #{key} -> #{value}")

    send_response(socket, value)

    "LSET #{key} #{index} #{value}"
  end

  def handle_line(["HSET", key | value], socket) do
    new_value = Utils.chunk_two(value)

    Database.hset(key, new_value)

    Logger.info("HSET #{key}")

    send_response(socket, "ok")

    values = Enum.map_join(value, " ", fn x -> x end)

    "HSET #{key} #{values}"
  end

  def handle_line(["HGET", key, field], socket) do
    value = Database.hget(key, field)

    Logger.info("HGET #{key} -> #{value}")

    send_response(socket, value)

    " "
  end

  def handle_line(["HGETALL", key], socket) do
    value = Database.hgetall(key)

    Logger.info("HGETALL #{key} -> #{Enum.map_join(value, ", ", fn {k, v} -> "#{k}: #{v}" end)}")

    Enum.each(value, fn {k, v} ->
      send_line_response(socket, k)
      send_line_response(socket, v)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["HDEL", key | fields], socket) do
    Database.hdel(key, fields)

    Logger.info("HDEL #{key}")

    send_response(socket, "ok")

    "HDEL #{key} #{Utils.list_to_string(fields)}"
  end

  def handle_line(["HLEN", key], socket) do
    count = Database.hlen(key)

    Logger.info("HLEN #{key} -> #{count}")

    send_response(socket, count)

    " "
  end

  def handle_line(["HEXISTS", key, field], socket) do
    value = Database.hexists(key, field)

    Logger.info("HEXISTS #{key} -> #{value}")

    send_response(socket, value)

    " "
  end

  def handle_line(["HKEYS", key], socket) do
    value = Database.hkeys(key)

    Logger.info("HKEYS #{key} -> #{value}")

    Enum.each(value, fn x ->
      send_line_response(socket, x)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["HVALS", key], socket) do
    value = Database.hvals(key)

    Logger.info("HVALS #{key} -> #{value}")

    Enum.each(value, fn x ->
      send_line_response(socket, x)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["SADD", key | values], socket) do
    value = Database.sadd(key, values)

    Logger.info("SADD #{key} -> #{value}")

    send_response(socket, value)

    "SADD #{key} #{Utils.list_to_string(values)}"
  end

  def handle_line(["SMEMBERS", key], socket) do
    value = Database.smembers(key)

    Logger.info("SMEMBERS #{key} -> #{value}")

    Enum.each(value, fn x ->
      send_line_response(socket, x)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["SREM", key | values], socket) do
    value = Database.srem(key, values)

    Logger.info("SREM #{key} -> #{value}")

    send_response(socket, value)

    "SREM #{key} #{Utils.list_to_string(values)}"
  end

  def handle_line(["SCARD", key], socket) do
    value = Database.scard(key)

    Logger.info("SCARD #{key} -> #{value}")

    send_response(socket, value)

    " "
  end

  def handle_line(["SDIFF" | keys], socket) do
    value = Database.sdiff(keys)

    Logger.info("SDIFF #{Utils.list_to_string(keys)} -> #{value}")

    Enum.each(value, fn x ->
      send_line_response(socket, x)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["SINTER" | keys], socket) do
    value = Database.sinter(keys)

    Logger.info("SINTER #{Utils.list_to_string(keys)} -> #{value}")

    Enum.each(value, fn x ->
      send_line_response(socket, x)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["SISMEMBER", key, value], socket) do
    value = Database.sismember(key, value)

    Logger.info("SISMEMBER #{key} -> #{value}")

    send_response(socket, value)

    " "
  end

  def handle_line(["SUNION" | keys], socket) do
    value = Database.sunion(keys)

    Logger.info("SUNION #{Utils.list_to_string(keys)} -> #{value}")

    Enum.each(value, fn x ->
      send_line_response(socket, x)
    end)

    send_empty_response(socket)

    " "
  end

  def handle_line(["EXIT"], socket) do
    Logger.info("EXIT")

    :gen_tcp.close(socket)

    :ok = Task.Supervisor.terminate_child(Allydb.Server.TaskSupervisor, self())

    "EXIT"
  end

  def handle_line(command, socket) do
    command = Utils.list_to_string(command)

    send_response(socket, "Invalid command: #{command}")

    " "
  end

  defp send_response(socket, value) do
    case socket do
      nil ->
        :ok

      _ ->
        :gen_tcp.send(socket, "#{value} #{@new_line}")
    end
  end

  defp send_line_response(socket, value) do
    case socket do
      nil ->
        :ok

      _ ->
        :gen_tcp.send(socket, "#{value}\n")
    end
  end

  defp send_empty_response(socket) do
    case socket do
      nil ->
        :ok

      _ ->
        :gen_tcp.send(socket, @new_line)
    end
  end
end
