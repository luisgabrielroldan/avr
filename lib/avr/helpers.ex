defmodule AVR.Helpers do
  @moduledoc false

  @doc """
  Compare two binaries and return `:equal` if they are equal or an error if they are different.
  """
  @spec binary_cmp(bin1 :: binary(), bin2 :: binary()) ::
          :equal | {:error, :size_mismatch} | {:error, {:mismatch, non_neg_integer()}}

  def binary_cmp(bin1, bin2) when byte_size(bin1) != byte_size(bin2),
    do: {:error, :size_mismatch}

  def binary_cmp(test, pattern),
    do: do_binary_cmp(test, pattern, 0)

  defp do_binary_cmp(<<>>, <<>>, _offset),
    do: :equal

  defp do_binary_cmp(<<b::8, rest_test::binary>>, <<b::8, rest_pattern::binary>>, offset),
    do: do_binary_cmp(rest_test, rest_pattern, offset + 1)

  defp do_binary_cmp(_, _, offset),
    do: {:error, {:mismatch, offset}}

  @doc """
  Read at least `min_bytes` bytes from the UART. 
  The caller is blocked until all the bytes are available or the timeout expired.
  """
  @spec read_min_bytes(
          port :: GenServer.server(),
          min_bytes :: pos_integer(),
          timeout :: non_neg_integer()
        ) ::
          {:ok, binary()} | {:error, term()}
  def read_min_bytes(port, min_bytes, timeout \\ 1000)
      when is_integer(min_bytes) and min_bytes > 0,
      do: do_read(port, min_bytes, timeout, <<>>)

  defp do_read(port, min_bytes, timeout, buffer) do
    call_time = System.monotonic_time(:millisecond)

    case Circuits.UART.read(port, timeout) do
      {:ok, data} ->
        elapsed = System.monotonic_time(:millisecond) - call_time
        buffer = <<buffer::binary, data::binary>>

        if byte_size(buffer) >= min_bytes do
          {:ok, buffer}
        else
          if elapsed < timeout do
            do_read(port, min_bytes, timeout - elapsed, buffer)
          else
            {:ok, buffer}
          end
        end

      error ->
        error
    end
  end

  def with_retry(attempts, fun),
    do: with_retry(attempts, fun, nil)

  def with_retry(attempts_left, fun, _error) when attempts_left > 0 do
    case fun.() do
      {:retry, error} ->
        with_retry(attempts_left - 1, fun, error)

      {:done, result} ->
        result
    end
  end

  def with_retry(_attempts_left, _fun, error),
    do: error
end
