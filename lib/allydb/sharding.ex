defmodule AllyDB.Sharding do
  @moduledoc """
  Provides functions for determining the shard for a given key.
  """

  @typedoc "Key for sharding operations."
  @type key :: any()

  @typedoc "Number of shards."
  @type num_shards :: pos_integer()

  @typedoc "Resulting shard index."
  @type shard_index :: non_neg_integer()

  @doc """
  Calculates the target shard index for a given key.
  """
  @spec hash_key_to_shard(key :: key(), num_shards :: num_shards()) :: shard_index()
  def hash_key_to_shard(key, num_shards) when num_shards > 0 do
    :erlang.phash2(key, num_shards)
  end
end
