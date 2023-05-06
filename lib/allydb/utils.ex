defmodule Allydb.Utils do
  @moduledoc false

  def chunk_two(value) do
    value |> Enum.chunk_every(2) |> Map.new(fn [k, v] -> {k, v} end)
  end

  def list_to_string(list) do
    Enum.map_join(list, " ", fn x -> x end)
  end

  def parse_line(line) do
    line
    |> String.split(" ")
    |> Enum.map(fn x -> String.trim(x) end)
    |> Enum.with_index()
    |> Enum.map(fn {x, i} -> if i == 0, do: String.upcase(x), else: x end)
  end

  def parse_line_with_end(line) do
    line
    |> String.slice(0..-2)
    |> parse_line()
  end
end
