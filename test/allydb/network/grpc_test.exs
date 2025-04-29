defmodule AllyDB.Network.GrpcTest do
  use ExUnit.Case

  alias AllyDB.Example.Counter
  alias AllyDB.Network.ProtoValueConverter

  alias AllyDB.{
    ActorService,
    ActorService.Stub,
    CallActorRequest,
    CastActorRequest,
    DatabaseService.Stub,
    DeleteRequest,
    GetRequest,
    SetRequest,
    StartActorRequest,
    StopActorRequest
  }

  require Logger

  @grpc_port Application.compile_env!(:allydb, :grpc)[:port]

  setup_all do
    Application.ensure_all_started(:allydb)
    Logger.info("AllyDB Application started for tests. Using gRPC port: #{@grpc_port}")
    :ok
  end

  setup do
    {:ok, channel} = GRPC.Stub.connect("localhost:#{@grpc_port}", interceptors: [])
    {:ok, %{channel: channel}}
  end

  defp to_val(term), do: ProtoValueConverter.to_proto_value(term)
  defp from_val(proto_val), do: ProtoValueConverter.from_proto_value(proto_val)

  defp unique_id(prefix) do
    "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"
  end

  describe "DatabaseService via gRPC" do
    test "Set and Get basic values", %{channel: channel} do
      key = unique_id("db_key")

      values = %{
        "string" => "hello world",
        "integer" => 123,
        "float" => 45.67,
        "boolean_true" => true,
        "boolean_false" => false,
        "atom" => :an_atom,
        "list" => [1, "two", true, :three],
        "tuple" => {:ok, 42},
        "tuple_with_atom" => {:add, 5},
        "map" => %{"a" => 1, "b" => "bee"},
        "nil_value" => nil
      }

      for {suffix, val} <- values do
        full_key = "#{key}_#{suffix}"
        req = %SetRequest{key: full_key, value: to_val(val)}
        assert {:ok, %AllyDB.SetResponse{result: {:ok, true}}} = Stub.set(channel, req)
      end

      for {suffix, original_val} <- values do
        full_key = "#{key}_#{suffix}"
        req = %GetRequest{key: full_key}
        {:ok, %AllyDB.GetResponse{result: {:value, proto_val}}} = Stub.get(channel, req)
        retrieved_val = from_val(proto_val)

        assert retrieved_val == original_val,
               "Mismatch for suffix '#{suffix}'. Expected: #{inspect(original_val)}, Got: #{inspect(retrieved_val)}"
      end
    end

    test "Get returns not_found for non-existent key", %{channel: channel} do
      key = unique_id("db_non_existent")
      req = %GetRequest{key: key}
      assert {:ok, %AllyDB.GetResponse{result: {:not_found, true}}} = Stub.get(channel, req)
    end

    test "Set overwrites existing value", %{channel: channel} do
      key = unique_id("db_overwrite")
      val1 = "initial value"
      val2 = %{"new" => "value"}

      req1 = %SetRequest{key: key, value: to_val(val1)}
      assert {:ok, %AllyDB.SetResponse{result: {:ok, true}}} = Stub.set(channel, req1)

      req2 = %SetRequest{key: key, value: to_val(val2)}
      assert {:ok, %AllyDB.SetResponse{result: {:ok, true}}} = Stub.set(channel, req2)

      get_req = %GetRequest{key: key}
      {:ok, %AllyDB.GetResponse{result: {:value, proto_val}}} = Stub.get(channel, get_req)
      assert from_val(proto_val) == val2
    end

    test "Delete removes a key", %{channel: channel} do
      key = unique_id("db_delete")
      value = "to be deleted"

      set_req = %SetRequest{key: key, value: to_val(value)}
      assert {:ok, %AllyDB.SetResponse{result: {:ok, true}}} = Stub.set(channel, set_req)

      del_req = %DeleteRequest{key: key}
      assert {:ok, %AllyDB.DeleteResponse{result: {:ok, true}}} = Stub.delete(channel, del_req)

      get_req = %GetRequest{key: key}
      assert {:ok, %AllyDB.GetResponse{result: {:not_found, true}}} = Stub.get(channel, get_req)
    end

    test "Delete returns ok for non-existent key", %{channel: channel} do
      key = unique_id("db_delete_non_existent")
      del_req = %DeleteRequest{key: key}
      assert {:ok, %AllyDB.DeleteResponse{result: {:ok, true}}} = Stub.delete(channel, del_req)
    end

    test "Set and Get with empty string key", %{channel: channel} do
      key = ""
      value = "value_for_empty_key"

      set_req = %SetRequest{key: key, value: to_val(value)}
      assert {:ok, %AllyDB.SetResponse{result: {:ok, true}}} = Stub.set(channel, set_req)

      get_req = %GetRequest{key: key}
      {:ok, %AllyDB.GetResponse{result: {:value, proto_val}}} = Stub.get(channel, get_req)
      assert from_val(proto_val) == value

      del_req = %DeleteRequest{key: key}
      assert {:ok, %AllyDB.DeleteResponse{result: {:ok, true}}} = Stub.delete(channel, del_req)
    end
  end

  describe "ActorService via gRPC" do
    setup %{channel: channel} do
      actor_id = unique_id("grpc_actor")
      init_args = actor_id
      module_name = Atom.to_string(Counter)

      start_req = %StartActorRequest{
        actor_id: actor_id,
        actor_module: module_name,
        init_args: to_val(init_args)
      }

      assert {:ok, %AllyDB.StartActorResponse{result: {:ok, true}}} =
               ActorService.Stub.start_actor(channel, start_req)

      {:ok, %{actor_id: actor_id, module_name: module_name}}
    end

    test "StartActor fails for already started actor", %{
      channel: channel,
      actor_id: actor_id,
      module_name: module_name
    } do
      start_req = %StartActorRequest{
        actor_id: actor_id,
        actor_module: module_name,
        init_args: to_val(actor_id)
      }

      assert {:ok, %AllyDB.StartActorResponse{result: {:already_started, true}}} =
               ActorService.Stub.start_actor(channel, start_req)
    end

    test "StartActor fails for invalid module", %{channel: channel} do
      actor_id = unique_id("invalid_actor")

      start_req = %StartActorRequest{
        actor_id: actor_id,
        actor_module: "Elixir.NonExistent.Module",
        init_args: to_val(nil)
      }

      assert {:ok, %AllyDB.StartActorResponse{result: {:start_failed_reason, reason}}} =
               ActorService.Stub.start_actor(channel, start_req)

      assert reason =~ "Invalid or unknown actor module"
    end

    test "CallActor interacts with actor state", %{channel: channel, actor_id: actor_id} do
      call_req_get1 = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val(:get),
        timeout_ms: 1000
      }

      {:ok, %AllyDB.CallActorResponse{result: {:reply_payload, reply1}}} =
        ActorService.Stub.call_actor(channel, call_req_get1)

      assert from_val(reply1) == {:ok, 0}

      call_req_inc = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val(:increment),
        timeout_ms: 1000
      }

      {:ok, %AllyDB.CallActorResponse{result: {:reply_payload, reply2}}} =
        ActorService.Stub.call_actor(channel, call_req_inc)

      assert from_val(reply2) == {:ok, 1}

      call_req_get2 = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val(:get),
        timeout_ms: 1000
      }

      {:ok, %AllyDB.CallActorResponse{result: {:reply_payload, reply3}}} =
        ActorService.Stub.call_actor(channel, call_req_get2)

      assert from_val(reply3) == {:ok, 1}
    end

    test "CastActor interacts with actor state", %{channel: channel, actor_id: actor_id} do
      cast_req_inc = %CastActorRequest{
        actor_id: actor_id,
        message_payload: to_val(:increment)
      }

      assert {:ok, %AllyDB.CastActorResponse{result: {:ok, true}}} =
               ActorService.Stub.cast_actor(channel, cast_req_inc)

      cast_req_reset = %CastActorRequest{
        actor_id: actor_id,
        message_payload: to_val(:reset)
      }

      assert {:ok, %AllyDB.CastActorResponse{result: {:ok, true}}} =
               ActorService.Stub.cast_actor(channel, cast_req_reset)

      Process.sleep(50)

      call_req_get = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val(:get),
        timeout_ms: 1000
      }

      {:ok, %AllyDB.CallActorResponse{result: {:reply_payload, reply}}} =
        ActorService.Stub.call_actor(channel, call_req_get)

      assert from_val(reply) == {:ok, 0}
    end

    test "CallActor supports atom and tuple commands", %{channel: channel, actor_id: actor_id} do
      call_req = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val(:get),
        timeout_ms: 1000
      }

      {:ok, %AllyDB.CallActorResponse{result: {:reply_payload, reply}}} =
        ActorService.Stub.call_actor(channel, call_req)

      assert from_val(reply) == {:ok, 0}

      call_req = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val({:add, 5}),
        timeout_ms: 1000
      }

      {:ok, %AllyDB.CallActorResponse{result: {:reply_payload, reply}}} =
        ActorService.Stub.call_actor(channel, call_req)

      assert from_val(reply) == {:ok, 5}
    end

    test "CastActor supports atom and tuple commands", %{channel: channel, actor_id: actor_id} do
      cast_req = %CastActorRequest{
        actor_id: actor_id,
        message_payload: to_val({:add, 5})
      }

      assert {:ok, %AllyDB.CastActorResponse{result: {:ok, true}}} =
               ActorService.Stub.cast_actor(channel, cast_req)

      call_req = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val(:get),
        timeout_ms: 1000
      }

      {:ok, %AllyDB.CallActorResponse{result: {:reply_payload, reply}}} =
        ActorService.Stub.call_actor(channel, call_req)

      assert from_val(reply) == {:ok, 5}
    end

    test "CallActor returns not_found for non-existent actor", %{channel: channel} do
      call_req = %CallActorRequest{
        actor_id: unique_id("non_existent_actor"),
        request_payload: to_val(:get),
        timeout_ms: 1000
      }

      assert {:ok, %AllyDB.CallActorResponse{result: {:actor_not_found, true}}} =
               ActorService.Stub.call_actor(channel, call_req)
    end

    test "CastActor returns not_found for non-existent actor", %{channel: channel} do
      cast_req = %CastActorRequest{
        actor_id: unique_id("non_existent_actor"),
        message_payload: to_val(:increment)
      }

      assert {:ok, %AllyDB.CastActorResponse{result: {:actor_not_found, true}}} =
               ActorService.Stub.cast_actor(channel, cast_req)
    end

    test "StopActor stops a running actor", %{channel: channel, actor_id: actor_id} do
      stop_req = %StopActorRequest{actor_id: actor_id}

      assert {:ok, %AllyDB.StopActorResponse{result: {:ok, true}}} =
               ActorService.Stub.stop_actor(channel, stop_req)

      call_req = %CallActorRequest{
        actor_id: actor_id,
        request_payload: to_val(:get),
        timeout_ms: 1000
      }

      assert {:ok, %AllyDB.CallActorResponse{result: {:actor_not_found, true}}} =
               ActorService.Stub.call_actor(channel, call_req)
    end

    test "StopActor returns not_found for non-existent actor", %{channel: channel} do
      stop_req = %StopActorRequest{actor_id: unique_id("non_existent_actor")}

      assert {:ok, %AllyDB.StopActorResponse{result: {:actor_not_found, true}}} =
               ActorService.Stub.stop_actor(channel, stop_req)
    end
  end
end
