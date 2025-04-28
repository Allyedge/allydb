defmodule AllyDB.Network.ProtoValueConverter do
  @moduledoc """
  Provides functions to convert between Elixir terms and `Google.Protobuf.Value` structs.

  Handles common Elixir types like nil, booleans, numbers, strings, atoms (as strings),
  lists (including tuples converted to lists), and maps (keys must be strings).
  """

  alias Google.Protobuf.{ListValue, NullValue, Struct, Value}

  @typedoc "An Elixir term supported for conversion."
  @type elixir_term ::
          nil
          | boolean()
          | number()
          | String.t()
          | atom()
          | list(elixir_term())
          | tuple()
          | %{required(String.t()) => elixir_term()}

  @typedoc "A Google Protobuf Value struct."
  @type proto_value :: Value.t() | nil

  @doc """
  Converts an Elixir term into a `Google.Protobuf.Value` struct.

  Raises `ArgumentError` if a map with non-string keys is encountered.
  """
  @spec to_proto_value(term :: elixir_term()) :: proto_value()
  def to_proto_value(nil),
    do: %Value{kind: {:null_value, NullValue.value(:NULL_VALUE)}}

  def to_proto_value(value) when is_boolean(value), do: %Value{kind: {:bool_value, value}}
  def to_proto_value(value) when is_integer(value), do: %Value{kind: {:number_value, value + 0.0}}
  def to_proto_value(value) when is_float(value), do: %Value{kind: {:number_value, value}}
  def to_proto_value(value) when is_binary(value), do: %Value{kind: {:string_value, value}}

  def to_proto_value(value) when is_atom(value),
    do: %Value{kind: {:string_value, Atom.to_string(value)}}

  def to_proto_value(list) when is_list(list) do
    proto_values = Enum.map(list, &to_proto_value/1)
    %Value{kind: {:list_value, %ListValue{values: proto_values}}}
  end

  def to_proto_value(tuple) when is_tuple(tuple) do
    list = Tuple.to_list(tuple)
    base = %{"__tuple__" => to_proto_value(true)}

    fields =
      Enum.with_index(list)
      |> Enum.reduce(base, fn {elem, idx}, acc ->
        Map.put(acc, Integer.to_string(idx), to_proto_value(elem))
      end)

    %Value{kind: {:struct_value, %Struct{fields: fields}}}
  end

  def to_proto_value(map) when is_map(map) do
    fields =
      map
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        unless is_binary(k) do
          raise ArgumentError,
                "Map keys must be strings; got #{inspect(k)}"
        end

        Map.put(acc, k, to_proto_value(v))
      end)

    %Value{kind: {:struct_value, %Struct{fields: fields}}}
  end

  def to_proto_value(other) do
    raise ArgumentError,
          "Unsupported Elixir type for Protobuf Value conversion: #{inspect(other)}"
  end

  @doc """
  Converts a `Google.Protobuf.Value` struct (or nil) back into an Elixir term.
  """
  @spec from_proto_value(value :: proto_value()) :: elixir_term()
  def from_proto_value(nil), do: nil

  def from_proto_value(%Value{kind: {:null_value, _}}), do: nil
  def from_proto_value(%Value{kind: {:number_value, num}}), do: num
  def from_proto_value(%Value{kind: {:string_value, str}}), do: str
  def from_proto_value(%Value{kind: {:bool_value, bool}}), do: bool

  def from_proto_value(%Value{kind: {:struct_value, %Struct{fields: fields}}}) do
    if Map.has_key?(fields, "__tuple__") do
      fields
      |> Map.delete("__tuple__")
      |> Enum.map(fn {k, v} -> {String.to_integer(k), from_proto_value(v)} end)
      |> Enum.sort_by(fn {idx, _} -> idx end)
      |> Enum.map(fn {_idx, val} -> val end)
      |> List.to_tuple()
    else
      fields
      |> Enum.into(%{}, fn {k, v} -> {k, from_proto_value(v)} end)
    end
  end

  def from_proto_value(%Value{kind: {:list_value, %ListValue{values: values}}}) do
    Enum.map(values, &from_proto_value/1)
  end

  def from_proto_value(%Value{kind: nil}), do: nil
end
