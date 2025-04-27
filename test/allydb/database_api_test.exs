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

  defp unique_key(prefix \\ "test_key") do
    "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
  end

  defp unique_value(prefix \\ "test_value") do
    "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
  end
end
