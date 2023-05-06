defmodule Allydb.MixProject do
  use Mix.Project

  def project do
    [
      app: :allydb,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Allydb.Application, []}
    ]
  end

  defp deps do
    [
      {:styler, "~> 0.5", only: [:dev, :test], runtime: false}
    ]
  end
end
