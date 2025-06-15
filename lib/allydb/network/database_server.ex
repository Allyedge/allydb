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
    LIndexRequest,
    LIndexResponse,
    LLenRequest,
    LLenResponse,
    LPopRequest,
    LPopResponse,
    LPushRequest,
    LPushResponse,
    LRangeRequest,
    LRangeResponse,
    ListValues,
    RPopRequest,
    RPopResponse,
    RPushRequest,
    RPushResponse,
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

  @doc "Handles the LPush RPC call."
  @spec l_push(LPushRequest.t(), grpc_stream()) :: LPushResponse.t()
  def l_push(%LPushRequest{key: key_str, values: proto_values}, _stream) do
    Logger.debug(
      "gRPC LPush Request: key=#{inspect(key_str)}, values count=#{length(proto_values)}"
    )

    try do
      values = Enum.map(proto_values, &ProtoValueConverter.from_proto_value/1)

      case DatabaseAPI.lpush(key_str, values) do
        {:ok, new_length} ->
          %LPushResponse{result: {:new_length, new_length}}

        {:error, :shard_unavailable} ->
          %LPushResponse{result: {:shard_unavailable, true}}

        {:error, {:shard_crash, reason}} ->
          %LPushResponse{result: {:shard_crash_reason, inspect(reason)}}
      end
    rescue
      e ->
        Logger.error(
          "gRPC LPush: Failed to convert values for key '#{key_str}'. Error: #{inspect(e)}"
        )

        %LPushResponse{
          result: {:shard_crash_reason, "Internal error: Failed to deserialize values"}
        }
    end
  end

  @doc "Handles the RPush RPC call."
  @spec r_push(RPushRequest.t(), grpc_stream()) :: RPushResponse.t()
  def r_push(%RPushRequest{key: key_str, values: proto_values}, _stream) do
    Logger.debug(
      "gRPC RPush Request: key=#{inspect(key_str)}, values count=#{length(proto_values)}"
    )

    try do
      values = Enum.map(proto_values, &ProtoValueConverter.from_proto_value/1)

      case DatabaseAPI.rpush(key_str, values) do
        {:ok, new_length} ->
          %RPushResponse{result: {:new_length, new_length}}

        {:error, :shard_unavailable} ->
          %RPushResponse{result: {:shard_unavailable, true}}

        {:error, {:shard_crash, reason}} ->
          %RPushResponse{result: {:shard_crash_reason, inspect(reason)}}
      end
    rescue
      e ->
        Logger.error(
          "gRPC RPush: Failed to convert values for key '#{key_str}'. Error: #{inspect(e)}"
        )

        %RPushResponse{
          result: {:shard_crash_reason, "Internal error: Failed to deserialize values"}
        }
    end
  end

  @doc "Handles the LPop RPC call."
  @spec l_pop(LPopRequest.t(), grpc_stream()) :: LPopResponse.t()
  def l_pop(%LPopRequest{key: key_str}, _stream) do
    Logger.debug("gRPC LPop Request: key=#{inspect(key_str)}")

    case DatabaseAPI.lpop(key_str) do
      {:ok, value} ->
        try do
          proto_value = ProtoValueConverter.to_proto_value(value)
          %LPopResponse{result: {:value, proto_value}}
        rescue
          e ->
            Logger.error(
              "gRPC LPop: Failed to convert value for key '#{key_str}'. Error: #{inspect(e)}"
            )

            %LPopResponse{
              result: {:shard_crash_reason, "Internal error: Failed to serialize response"}
            }
        end

      {:error, :not_found} ->
        %LPopResponse{result: {:not_found, true}}

      {:error, :empty_list} ->
        %LPopResponse{result: {:empty_list, true}}

      {:error, :shard_unavailable} ->
        %LPopResponse{result: {:shard_unavailable, true}}

      {:error, {:shard_crash, reason}} ->
        %LPopResponse{result: {:shard_crash_reason, inspect(reason)}}
    end
  end

  @doc "Handles the RPop RPC call."
  @spec r_pop(RPopRequest.t(), grpc_stream()) :: RPopResponse.t()
  def r_pop(%RPopRequest{key: key_str}, _stream) do
    Logger.debug("gRPC RPop Request: key=#{inspect(key_str)}")

    case DatabaseAPI.rpop(key_str) do
      {:ok, value} ->
        try do
          proto_value = ProtoValueConverter.to_proto_value(value)
          %RPopResponse{result: {:value, proto_value}}
        rescue
          e ->
            Logger.error(
              "gRPC RPop: Failed to convert value for key '#{key_str}'. Error: #{inspect(e)}"
            )

            %RPopResponse{
              result: {:shard_crash_reason, "Internal error: Failed to serialize response"}
            }
        end

      {:error, :not_found} ->
        %RPopResponse{result: {:not_found, true}}

      {:error, :empty_list} ->
        %RPopResponse{result: {:empty_list, true}}

      {:error, :shard_unavailable} ->
        %RPopResponse{result: {:shard_unavailable, true}}

      {:error, {:shard_crash, reason}} ->
        %RPopResponse{result: {:shard_crash_reason, inspect(reason)}}
    end
  end

  @doc "Handles the LLen RPC call."
  @spec l_len(LLenRequest.t(), grpc_stream()) :: LLenResponse.t()
  def l_len(%LLenRequest{key: key_str}, _stream) do
    Logger.debug("gRPC LLen Request: key=#{inspect(key_str)}")

    case DatabaseAPI.llen(key_str) do
      {:ok, length} ->
        %LLenResponse{result: {:length, length}}

      {:error, :not_found} ->
        %LLenResponse{result: {:not_found, true}}

      {:error, :shard_unavailable} ->
        %LLenResponse{result: {:shard_unavailable, true}}

      {:error, {:shard_crash, reason}} ->
        %LLenResponse{result: {:shard_crash_reason, inspect(reason)}}
    end
  end

  @doc "Handles the LIndex RPC call."
  @spec l_index(LIndexRequest.t(), grpc_stream()) :: LIndexResponse.t()
  def l_index(%LIndexRequest{key: key_str, index: index}, _stream) do
    Logger.debug("gRPC LIndex Request: key=#{inspect(key_str)}, index=#{index}")

    case DatabaseAPI.lindex(key_str, index) do
      {:ok, value} ->
        try do
          proto_value = ProtoValueConverter.to_proto_value(value)
          %LIndexResponse{result: {:value, proto_value}}
        rescue
          e ->
            Logger.error(
              "gRPC LIndex: Failed to convert value for key '#{key_str}'. Error: #{inspect(e)}"
            )

            %LIndexResponse{
              result: {:shard_crash_reason, "Internal error: Failed to serialize response"}
            }
        end

      {:error, :not_found} ->
        %LIndexResponse{result: {:not_found, true}}

      {:error, :index_out_of_range} ->
        %LIndexResponse{result: {:index_out_of_range, true}}

      {:error, :shard_unavailable} ->
        %LIndexResponse{result: {:shard_unavailable, true}}

      {:error, {:shard_crash, reason}} ->
        %LIndexResponse{result: {:shard_crash_reason, inspect(reason)}}
    end
  end

  @doc "Handles the LRange RPC call."
  @spec l_range(LRangeRequest.t(), grpc_stream()) :: LRangeResponse.t()
  def l_range(%LRangeRequest{key: key_str, start: start, stop: stop}, _stream) do
    Logger.debug("gRPC LRange Request: key=#{inspect(key_str)}, start=#{start}, stop=#{stop}")

    case DatabaseAPI.lrange(key_str, start, stop) do
      {:ok, values} ->
        try do
          proto_values = Enum.map(values, &ProtoValueConverter.to_proto_value/1)
          list_values = %ListValues{values: proto_values}
          %LRangeResponse{result: {:values, list_values}}
        rescue
          e ->
            Logger.error(
              "gRPC LRange: Failed to convert values for key '#{key_str}'. Error: #{inspect(e)}"
            )

            %LRangeResponse{
              result: {:shard_crash_reason, "Internal error: Failed to serialize response"}
            }
        end

      {:error, :not_found} ->
        %LRangeResponse{result: {:not_found, true}}

      {:error, :shard_unavailable} ->
        %LRangeResponse{result: {:shard_unavailable, true}}

      {:error, {:shard_crash, reason}} ->
        %LRangeResponse{result: {:shard_crash_reason, inspect(reason)}}
    end
  end
end
