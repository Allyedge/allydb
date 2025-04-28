# lib/allydb/network/endpoint.ex
defmodule AllyDB.Network.Endpoint do
  @moduledoc """
  Defines the gRPC Endpoint for AllyDB.

  Specifies the service implementations and any interceptors.
  """

  use GRPC.Endpoint

  intercept(GRPC.Server.Interceptors.Logger)

  run(AllyDB.Network.DatabaseServer)
  run(AllyDB.Network.ActorServer)
end
