defmodule AllyDB.Network.ActorServer do
  @moduledoc "Implements the ActorService gRPC service."

  use GRPC.Server, service: AllyDB.ActorService.Service

  alias AllyDB.Network.ProtoValueConverter

  alias AllyDB.{
    ActorAPI,
    CallActorRequest,
    CallActorResponse,
    CastActorRequest,
    CastActorResponse,
    StartActorRequest,
    StartActorResponse,
    StopActorRequest,
    StopActorResponse
  }

  require Logger

  @type grpc_stream :: GRPC.Server.Stream.t()

  @doc "Handles the StartActor RPC call."
  @spec start_actor(StartActorRequest.t(), grpc_stream()) :: StartActorResponse.t()
  def start_actor(
        %StartActorRequest{
          actor_id: actor_id_str,
          actor_module: actor_module_str,
          init_args: proto_init_args
        },
        _stream
      ) do
    Logger.debug("gRPC StartActor Request: id=#{actor_id_str}, module=#{actor_module_str}")

    init_args = ProtoValueConverter.from_proto_value(proto_init_args)

    try do
      actor_module = String.to_existing_atom(actor_module_str)

      case ActorAPI.start_actor(actor_id_str, actor_module, init_args) do
        {:ok, _pid} ->
          %StartActorResponse{result: {:ok, true}}

        {:error, {:already_started, _pid}} ->
          %StartActorResponse{result: {:already_started, true}}

        {:error, {:start_failed, reason}} ->
          %StartActorResponse{result: {:start_failed_reason, inspect(reason)}}
      end
    rescue
      e ->
        Logger.error(
          "gRPC StartActor: Module '#{actor_module_str}' does not exist or is not loaded. Error: #{inspect(e)}"
        )

        %StartActorResponse{
          result: {:start_failed_reason, "Invalid or unknown actor module"}
        }
    end
  end

  @doc "Handles the StopActor RPC call."
  @spec stop_actor(StopActorRequest.t(), grpc_stream()) :: StopActorResponse.t()
  def stop_actor(%StopActorRequest{actor_id: actor_id_str}, _stream) do
    Logger.debug("gRPC StopActor Request: id=#{actor_id_str}")

    case ActorAPI.stop_actor(actor_id_str) do
      :ok -> %StopActorResponse{result: {:ok, true}}
      {:error, :actor_not_found} -> %StopActorResponse{result: {:actor_not_found, true}}
    end
  end

  @doc "Handles the CallActor RPC call."
  @spec call_actor(CallActorRequest.t(), grpc_stream()) :: CallActorResponse.t()
  def call_actor(
        %CallActorRequest{
          actor_id: actor_id_str,
          request_payload: proto_request,
          timeout_ms: timeout
        },
        _stream
      ) do
    Logger.debug("gRPC CallActor Request: id=#{actor_id_str}")
    effective_timeout = if timeout <= 0, do: :infinity, else: timeout

    request = ProtoValueConverter.from_proto_value(proto_request)

    case ActorAPI.call(actor_id_str, request, effective_timeout) do
      {:ok, reply} ->
        try do
          %CallActorResponse{result: {:reply_payload, ProtoValueConverter.to_proto_value(reply)}}
        rescue
          e ->
            Logger.error(
              "gRPC CallActor: Failed to convert actor reply to Protobuf Value for actor '#{actor_id_str}'. Error: #{inspect(e)}"
            )

            %CallActorResponse{
              result: {:actor_crash_reason, "Internal error: Failed to serialize response"}
            }
        end

      {:error, :actor_not_found} ->
        %CallActorResponse{result: {:actor_not_found, true}}

      {:error, :call_timeout} ->
        %CallActorResponse{result: {:call_timeout, true}}

      {:error, {:actor_crash, reason}} ->
        %CallActorResponse{result: {:actor_crash_reason, inspect(reason)}}
    end
  end

  @doc "Handles the CastActor RPC call."
  @spec cast_actor(CastActorRequest.t(), grpc_stream()) :: CastActorResponse.t()
  def cast_actor(
        %CastActorRequest{
          actor_id: actor_id_str,
          message_payload: proto_message
        },
        _stream
      ) do
    Logger.debug("gRPC CastActor Request: id=#{actor_id_str}")

    message = ProtoValueConverter.from_proto_value(proto_message)

    case ActorAPI.cast(actor_id_str, message) do
      :ok ->
        %CastActorResponse{result: {:ok, true}}

      {:error, :actor_not_found} ->
        %CastActorResponse{result: {:actor_not_found, true}}
    end
  end
end
