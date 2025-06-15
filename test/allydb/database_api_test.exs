defmodule AllyDB.DatabaseAPITest do
  use ExUnit.Case, async: true

  alias AllyDB.DatabaseAPI

  setup_all do
    Application.ensure_all_started(:allydb)
    :ok
  end

  test "set/2 stores a value and get/1 retrieves it" do
    key = unique_key()
    value = unique_value()

    assert :ok = DatabaseAPI.set(key, value)
    assert {:ok, ^value} = DatabaseAPI.get(key)
  end

  test "get/1 returns not_found for a non-existent key" do
    assert {:error, :not_found} = DatabaseAPI.get(unique_key("get_non_existent"))
  end

  test "set/2 overwrites an existing value" do
    key = unique_key("set_overwrite")
    initial_value = unique_value("initial")
    new_value = unique_value()

    assert :ok = DatabaseAPI.set(key, initial_value)
    assert {:ok, ^initial_value} = DatabaseAPI.get(key)

    assert :ok = DatabaseAPI.set(key, new_value)
    assert {:ok, ^new_value} = DatabaseAPI.get(key)
  end

  test "delete/1 removes a key" do
    key = unique_key("delete_key")
    value = "to_be_deleted"

    assert :ok = DatabaseAPI.set(key, value)
    assert {:ok, ^value} = DatabaseAPI.get(key)

    assert :ok = DatabaseAPI.delete(key)
    assert {:error, :not_found} = DatabaseAPI.get(key)
  end

  test "delete/1 returns :ok for a non-existent key" do
    key = unique_key("non_existent_delete_key")

    assert :ok = DatabaseAPI.delete(key)
    assert {:error, :not_found} = DatabaseAPI.get(key)
  end

  test "lpush/2 creates a new list and returns the length" do
    key = unique_key("lpush_new")
    values = ["item1", "item2", "item3"]

    assert {:ok, 3} = DatabaseAPI.lpush(key, values)
  end

  test "rpush/2 creates a new list and returns the length" do
    key = unique_key("rpush_new")
    values = ["item1", "item2", "item3"]

    assert {:ok, 3} = DatabaseAPI.rpush(key, values)
  end

  test "lpush/2 and rpush/2 add to existing list" do
    key = unique_key("push_existing")

    assert {:ok, 2} = DatabaseAPI.rpush(key, ["item1", "item2"])

    assert {:ok, 4} = DatabaseAPI.lpush(key, ["item0", "item-1"])

    assert {:ok, 6} = DatabaseAPI.rpush(key, ["item3", "item4"])
  end

  test "lpop/1 removes and returns element from left" do
    key = unique_key("lpop_test")

    assert {:ok, 3} = DatabaseAPI.lpush(key, ["a", "b", "c"])

    assert {:ok, "c"} = DatabaseAPI.lpop(key)
    assert {:ok, "b"} = DatabaseAPI.lpop(key)
    assert {:ok, "a"} = DatabaseAPI.lpop(key)

    assert {:error, :empty_list} = DatabaseAPI.lpop(key)
  end

  test "rpop/1 removes and returns element from right" do
    key = unique_key("rpop_test")

    assert {:ok, 3} = DatabaseAPI.rpush(key, ["a", "b", "c"])

    assert {:ok, "c"} = DatabaseAPI.rpop(key)
    assert {:ok, "b"} = DatabaseAPI.rpop(key)
    assert {:ok, "a"} = DatabaseAPI.rpop(key)

    assert {:error, :empty_list} = DatabaseAPI.rpop(key)
  end

  test "llen/1 returns the length of a list" do
    key = unique_key("llen_test")

    assert {:error, :not_found} = DatabaseAPI.llen(key)

    assert {:ok, 3} = DatabaseAPI.rpush(key, ["a", "b", "c"])
    assert {:ok, 3} = DatabaseAPI.llen(key)

    assert {:ok, "c"} = DatabaseAPI.rpop(key)
    assert {:ok, 2} = DatabaseAPI.llen(key)

    assert {:ok, "b"} = DatabaseAPI.rpop(key)
    assert {:ok, "a"} = DatabaseAPI.rpop(key)
    assert {:ok, 0} = DatabaseAPI.llen(key)
  end

  test "lindex/2 returns element at specific index" do
    key = unique_key("lindex_test")

    assert {:error, :not_found} = DatabaseAPI.lindex(key, 0)

    assert {:ok, 4} = DatabaseAPI.rpush(key, ["a", "b", "c", "d"])

    assert {:ok, "a"} = DatabaseAPI.lindex(key, 0)
    assert {:ok, "b"} = DatabaseAPI.lindex(key, 1)
    assert {:ok, "c"} = DatabaseAPI.lindex(key, 2)
    assert {:ok, "d"} = DatabaseAPI.lindex(key, 3)

    assert {:ok, "d"} = DatabaseAPI.lindex(key, -1)
    assert {:ok, "c"} = DatabaseAPI.lindex(key, -2)
    assert {:ok, "b"} = DatabaseAPI.lindex(key, -3)
    assert {:ok, "a"} = DatabaseAPI.lindex(key, -4)

    assert {:error, :index_out_of_range} = DatabaseAPI.lindex(key, 4)
    assert {:error, :index_out_of_range} = DatabaseAPI.lindex(key, -5)
  end

  test "lrange/3 returns slice of list" do
    key = unique_key("lrange_test")

    assert {:error, :not_found} = DatabaseAPI.lrange(key, 0, -1)

    assert {:ok, 5} = DatabaseAPI.rpush(key, ["a", "b", "c", "d", "e"])

    assert {:ok, ["a", "b", "c", "d", "e"]} = DatabaseAPI.lrange(key, 0, -1)
    assert {:ok, ["a", "b", "c", "d", "e"]} = DatabaseAPI.lrange(key, 0, 4)

    assert {:ok, ["b", "c", "d"]} = DatabaseAPI.lrange(key, 1, 3)
    assert {:ok, ["c", "d", "e"]} = DatabaseAPI.lrange(key, 2, -1)
    assert {:ok, ["d", "e"]} = DatabaseAPI.lrange(key, -2, -1)

    assert {:ok, ["c"]} = DatabaseAPI.lrange(key, 2, 2)

    assert {:ok, []} = DatabaseAPI.lrange(key, 10, 15)
  end

  test "list operations work with different data types" do
    key = unique_key("mixed_types")

    values = [42, "string", true, %{"key" => "value"}]
    assert {:ok, 4} = DatabaseAPI.rpush(key, values)

    assert {:ok, 42} = DatabaseAPI.lindex(key, 0)
    assert {:ok, "string"} = DatabaseAPI.lindex(key, 1)
    assert {:ok, true} = DatabaseAPI.lindex(key, 2)
    assert {:ok, %{"key" => "value"}} = DatabaseAPI.lindex(key, 3)
  end

  defp unique_key(prefix \\ "test_key") do
    "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
  end

  defp unique_value(prefix \\ "test_value") do
    "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
  end
end
