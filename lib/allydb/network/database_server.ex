defmodule AllyDB.Network.DatabaseServer do
  @moduledoc "Implements the DatabaseService gRPC service."

  use GRPC.Server, service: AllyDB.DatabaseService.Service

  alias AllyDB.Network.ProtoValueConverter

  alias AllyDB.{
    DatabaseAPI,
    DeleteRequest,
    DeleteResponse,
    GetRequest,
    GetResponse,
    SetRequest,
    SetResponse
  }

  require Logger

  @type grpc_stream :: GRPC.Server.Stream.t()

  @doc "Handles the Get RPC call."
  @spec get(GetRequest.t(), grpc_stream()) :: GetResponse.t()
  def get(%GetRequest{key: key_str}, _stream) do
    Logger.debug("gRPC Get Request: key=#{inspect(key_str)}")

    case DatabaseAPI.get(key_str) do
      {:ok, value} ->
        try do
          proto_value = ProtoValueConverter.to_proto_value(value)
          %GetResponse{result: {:value, proto_value}}
        rescue
          e ->
            Logger.error(
              "gRPC Get: Failed to convert Elixir term to Protobuf Value for key '#{key_str}'. Error: #{inspect(e)}"
            )

            %GetResponse{
              result: {:shard_crash_reason, "Internal error: Failed to serialize response"}
            }
        end

      {:error, :not_found} ->
        %GetResponse{result: {:not_found, true}}

      {:error, :shard_unavailable} ->
        %GetResponse{result: {:shard_unavailable, true}}

      {:error, {:shard_crash, reason}} ->
        %GetResponse{result: {:shard_crash_reason, inspect(reason)}}
    end
  end

  @doc "Handles the Set RPC call."
  @spec set(SetRequest.t(), grpc_stream()) :: SetResponse.t()
  def set(%SetRequest{key: key_str, value: proto_value}, _stream) do
    Logger.debug("gRPC Set Request: key=#{inspect(key_str)}")

    value = ProtoValueConverter.from_proto_value(proto_value)

    case DatabaseAPI.set(key_str, value) do
      :ok -> %SetResponse{result: {:ok, true}}
      {:error, :shard_unavailable} -> %SetResponse{result: {:shard_unavailable, true}}
    end
  end

  @doc "Handles the Delete RPC call."
  @spec delete(DeleteRequest.t(), grpc_stream()) :: DeleteResponse.t()
  def delete(%DeleteRequest{key: key_str}, _stream) do
    Logger.debug("gRPC Delete Request: key=#{inspect(key_str)}")

    case DatabaseAPI.delete(key_str) do
      :ok -> %DeleteResponse{result: {:ok, true}}
      {:error, :shard_unavailable} -> %DeleteResponse{result: {:shard_unavailable, true}}
    end
  end
end
