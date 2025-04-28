defmodule AllyDB.MixProject do
  use Mix.Project

  def project do
    [
      app: :allydb,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :observer, :wx, :grpc, :ssl],
      mod: {AllyDB.Application, []}
    ]
  end

  defp aliases do
    [
      "proto.install": "escript.install hex protobuf 0.14.0",
      "proto.generate":
        "cmd protoc --elixir_out=plugins=grpc:./lib/allydb/grpc ./proto/allydb.proto"
    ]
  end

  defp deps do
    [
      {:protobuf, "~> 0.14"},
      {:grpc, "~> 0.9"},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
