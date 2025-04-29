defmodule AllyDB.ActorAPITest do
  use ExUnit.Case, async: true

  alias AllyDB.ActorAPI
  alias AllyDB.Core.ProcessManager
  alias AllyDB.Example.Counter

  setup do
    :ok
  end

  describe "start_actor/3" do
    test "successfully starts and registers a new actor" do
      actor_id = unique_actor_id()
      assert {:ok, pid} = ActorAPI.start_actor(actor_id, Counter, actor_id)
      assert is_pid(pid)

      assert [{^pid, _}] = ProcessManager.lookup_process(actor_id)

      ref = Process.monitor(pid)

      assert :ok = ActorAPI.stop_actor(actor_id)

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000

      Process.sleep(50)

      assert [] == ProcessManager.lookup_process(actor_id)
    end

    test "returns error when starting with an already used ID" do
      actor_id = unique_actor_id()
      {:ok, pid1} = ActorAPI.start_actor(actor_id, Counter, actor_id)
      assert is_pid(pid1)

      assert {:error, {:already_started, _pid}} =
               ActorAPI.start_actor(actor_id, Counter, actor_id)

      assert :ok = ActorAPI.stop_actor(actor_id)
    end
  end

  describe "stop_actor/1" do
    test "successfully stops a running actor" do
      actor_id = unique_actor_id()
      {:ok, pid} = ActorAPI.start_actor(actor_id, Counter, actor_id)
      assert is_pid(pid)
      assert Process.alive?(pid)

      assert :ok = ActorAPI.stop_actor(actor_id)

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 50
      Process.sleep(10)
      assert [] == ProcessManager.lookup_process(actor_id)
    end

    test "returns error when stopping a non-existent actor ID" do
      actor_id = unique_actor_id()
      assert {:error, :actor_not_found} = ActorAPI.stop_actor(actor_id)
    end
  end

  describe "call/3" do
    setup do
      actor_id = unique_actor_id()
      {:ok, pid} = ActorAPI.start_actor(actor_id, Counter, actor_id)

      on_exit(fn ->
        _ = ActorAPI.stop_actor(actor_id)
      end)

      {:ok, %{actor_id: actor_id, pid: pid}}
    end

    test "successfully calls an actor and gets a reply", %{actor_id: actor_id} do
      assert {:ok, {:ok, 0}} = ActorAPI.call(actor_id, :get)
      assert {:ok, {:ok, 1}} = ActorAPI.call(actor_id, :increment)
      assert {:ok, {:ok, 1}} = ActorAPI.call(actor_id, :get)
    end

    test "returns error when calling a non-existent actor ID" do
      non_existent_id = unique_actor_id("non_existent")
      assert {:error, :actor_not_found} = ActorAPI.call(non_existent_id, "get")
    end

    test "returns error on timeout", %{actor_id: actor_id} do
      assert {:error, :call_timeout} = ActorAPI.call(actor_id, "get", 0)
    end
  end

  describe "cast/2" do
    setup do
      actor_id = unique_actor_id()
      {:ok, pid} = ActorAPI.start_actor(actor_id, Counter, actor_id)

      on_exit(fn ->
        _ = ActorAPI.stop_actor(actor_id)
      end)

      {:ok, %{actor_id: actor_id, pid: pid}}
    end

    test "successfully casts to an actor and state changes", %{actor_id: actor_id} do
      assert {:ok, {:ok, 0}} = ActorAPI.call(actor_id, :get)

      assert :ok = ActorAPI.cast(actor_id, :increment)
      assert :ok = ActorAPI.cast(actor_id, :increment)
      assert :ok = ActorAPI.cast(actor_id, :reset)
      assert :ok = ActorAPI.cast(actor_id, :increment)

      Process.sleep(10)

      assert {:ok, {:ok, 1}} = ActorAPI.call(actor_id, :get)
    end

    test "returns error when casting to a non-existent actor ID" do
      non_existent_id = unique_actor_id("non_existent")
      assert {:error, :actor_not_found} = ActorAPI.cast(non_existent_id, "increment")
    end
  end

  defp unique_actor_id(base \\ "test_counter") do
    "#{base}_#{System.unique_integer([:positive])}"
  end
end
