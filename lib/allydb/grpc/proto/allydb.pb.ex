defmodule AllyDB.GetRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
end

defmodule AllyDB.GetResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:value, 1, type: Google.Protobuf.Value, oneof: 0)
  field(:not_found, 2, type: :bool, json_name: "notFound", oneof: 0)
  field(:shard_unavailable, 3, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 4, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.SetRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
  field(:value, 2, type: Google.Protobuf.Value)
end

defmodule AllyDB.SetResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:ok, 1, type: :bool, oneof: 0)
  field(:shard_unavailable, 2, type: :bool, json_name: "shardUnavailable", oneof: 0)
end

defmodule AllyDB.DeleteRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
end

defmodule AllyDB.DeleteResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:ok, 1, type: :bool, oneof: 0)
  field(:shard_unavailable, 2, type: :bool, json_name: "shardUnavailable", oneof: 0)
end

defmodule AllyDB.LPushRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
  field(:values, 2, repeated: true, type: Google.Protobuf.Value)
end

defmodule AllyDB.LPushResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:new_length, 1, type: :int64, json_name: "newLength", oneof: 0)
  field(:shard_unavailable, 2, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 3, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.RPushRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
  field(:values, 2, repeated: true, type: Google.Protobuf.Value)
end

defmodule AllyDB.RPushResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:new_length, 1, type: :int64, json_name: "newLength", oneof: 0)
  field(:shard_unavailable, 2, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 3, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.LPopRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
end

defmodule AllyDB.LPopResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:value, 1, type: Google.Protobuf.Value, oneof: 0)
  field(:empty_list, 2, type: :bool, json_name: "emptyList", oneof: 0)
  field(:not_found, 3, type: :bool, json_name: "notFound", oneof: 0)
  field(:shard_unavailable, 4, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 5, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.RPopRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
end

defmodule AllyDB.RPopResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:value, 1, type: Google.Protobuf.Value, oneof: 0)
  field(:empty_list, 2, type: :bool, json_name: "emptyList", oneof: 0)
  field(:not_found, 3, type: :bool, json_name: "notFound", oneof: 0)
  field(:shard_unavailable, 4, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 5, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.LLenRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
end

defmodule AllyDB.LLenResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:length, 1, type: :int64, oneof: 0)
  field(:not_found, 2, type: :bool, json_name: "notFound", oneof: 0)
  field(:shard_unavailable, 3, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 4, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.LIndexRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
  field(:index, 2, type: :int64)
end

defmodule AllyDB.LIndexResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:value, 1, type: Google.Protobuf.Value, oneof: 0)
  field(:index_out_of_range, 2, type: :bool, json_name: "indexOutOfRange", oneof: 0)
  field(:not_found, 3, type: :bool, json_name: "notFound", oneof: 0)
  field(:shard_unavailable, 4, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 5, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.LRangeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:key, 1, type: :string)
  field(:start, 2, type: :int64)
  field(:stop, 3, type: :int64)
end

defmodule AllyDB.LRangeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:values, 1, type: AllyDB.ListValues, oneof: 0)
  field(:not_found, 2, type: :bool, json_name: "notFound", oneof: 0)
  field(:shard_unavailable, 3, type: :bool, json_name: "shardUnavailable", oneof: 0)
  field(:shard_crash_reason, 4, type: :string, json_name: "shardCrashReason", oneof: 0)
end

defmodule AllyDB.ListValues do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:values, 1, repeated: true, type: Google.Protobuf.Value)
end

defmodule AllyDB.StartActorRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:actor_id, 1, type: :string, json_name: "actorId")
  field(:actor_module, 2, type: :string, json_name: "actorModule")
  field(:init_args, 3, type: Google.Protobuf.Value, json_name: "initArgs")
end

defmodule AllyDB.StartActorResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:ok, 1, type: :bool, oneof: 0)
  field(:already_started, 2, type: :bool, json_name: "alreadyStarted", oneof: 0)
  field(:start_failed_reason, 3, type: :string, json_name: "startFailedReason", oneof: 0)
end

defmodule AllyDB.StopActorRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:actor_id, 1, type: :string, json_name: "actorId")
end

defmodule AllyDB.StopActorResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:ok, 1, type: :bool, oneof: 0)
  field(:actor_not_found, 2, type: :bool, json_name: "actorNotFound", oneof: 0)
end

defmodule AllyDB.CallActorRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:actor_id, 1, type: :string, json_name: "actorId")
  field(:request_payload, 2, type: Google.Protobuf.Value, json_name: "requestPayload")
  field(:timeout_ms, 3, type: :int64, json_name: "timeoutMs")
end

defmodule AllyDB.CallActorResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:reply_payload, 1, type: Google.Protobuf.Value, json_name: "replyPayload", oneof: 0)
  field(:actor_not_found, 2, type: :bool, json_name: "actorNotFound", oneof: 0)
  field(:call_timeout, 3, type: :bool, json_name: "callTimeout", oneof: 0)
  field(:actor_crash_reason, 4, type: :string, json_name: "actorCrashReason", oneof: 0)
end

defmodule AllyDB.CastActorRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field(:actor_id, 1, type: :string, json_name: "actorId")
  field(:message_payload, 2, type: Google.Protobuf.Value, json_name: "messagePayload")
end

defmodule AllyDB.CastActorResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  oneof(:result, 0)

  field(:ok, 1, type: :bool, oneof: 0)
  field(:actor_not_found, 2, type: :bool, json_name: "actorNotFound", oneof: 0)
end

defmodule AllyDB.DatabaseService.Service do
  @moduledoc false

  use GRPC.Service, name: "AllyDB.DatabaseService", protoc_gen_elixir_version: "0.14.0"

  rpc(:Get, AllyDB.GetRequest, AllyDB.GetResponse)

  rpc(:Set, AllyDB.SetRequest, AllyDB.SetResponse)

  rpc(:Delete, AllyDB.DeleteRequest, AllyDB.DeleteResponse)

  rpc(:LPush, AllyDB.LPushRequest, AllyDB.LPushResponse)

  rpc(:RPush, AllyDB.RPushRequest, AllyDB.RPushResponse)

  rpc(:LPop, AllyDB.LPopRequest, AllyDB.LPopResponse)

  rpc(:RPop, AllyDB.RPopRequest, AllyDB.RPopResponse)

  rpc(:LLen, AllyDB.LLenRequest, AllyDB.LLenResponse)

  rpc(:LIndex, AllyDB.LIndexRequest, AllyDB.LIndexResponse)

  rpc(:LRange, AllyDB.LRangeRequest, AllyDB.LRangeResponse)
end

defmodule AllyDB.DatabaseService.Stub do
  @moduledoc false

  use GRPC.Stub, service: AllyDB.DatabaseService.Service
end

defmodule AllyDB.ActorService.Service do
  @moduledoc false

  use GRPC.Service, name: "AllyDB.ActorService", protoc_gen_elixir_version: "0.14.0"

  rpc(:StartActor, AllyDB.StartActorRequest, AllyDB.StartActorResponse)

  rpc(:StopActor, AllyDB.StopActorRequest, AllyDB.StopActorResponse)

  rpc(:CallActor, AllyDB.CallActorRequest, AllyDB.CallActorResponse)

  rpc(:CastActor, AllyDB.CastActorRequest, AllyDB.CastActorResponse)
end

defmodule AllyDB.ActorService.Stub do
  @moduledoc false

  use GRPC.Stub, service: AllyDB.ActorService.Service
end
