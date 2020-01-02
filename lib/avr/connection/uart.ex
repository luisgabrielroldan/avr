defmodule AVR.Connection.UART do
  @moduledoc false

  alias AVR.Connection
  alias Circuits.UART

  @behaviour Connection

  def open(port_name, opts) do
    with {:ok, ref} <- UART.start_link(),
         :ok <- UART.open(ref, port_name, opts) do
      {:ok, ref}
    end
  end

  def close(ref) do
    with :ok <- UART.close(ref),
         :ok <- UART.stop(ref) do
      :ok
    end
  end

  def send(ref, data),
    do: UART.write(ref, data)

  def recv(ref, timeout \\ 3000),
    do: UART.read(ref, timeout)

  def drain(ref),
    do: UART.drain(ref)

  def set_dtr(ref, state),
    do: UART.set_dtr(ref, state)

  def set_rts(ref, state),
    do: UART.set_rts(ref, state)

  @doc """
  Read at least `min_bytes` bytes from the UART. 
  The caller is blocked until all the bytes are available or the timeout expired.
  """
  @spec read_min_bytes(Connection.t(), min_bytes :: non_neg_integer, timeout :: non_neg_integer) ::
          {:ok, binary()} | {:error, term()}
  def read_min_bytes(ref, min_bytes, timeout \\ 1000)
      when is_integer(min_bytes) and min_bytes > 0,
      do: do_read(ref, min_bytes, timeout, <<>>)

  defp do_read(ref, min_bytes, timeout, buffer) do
    call_time = System.monotonic_time(:millisecond)

    case recv(ref, timeout) do
      {:ok, data} ->
        elapsed = System.monotonic_time(:millisecond) - call_time
        buffer = <<buffer::binary, data::binary>>

        if byte_size(buffer) >= min_bytes do
          {:ok, buffer}
        else
          if elapsed < timeout do
            do_read(ref, min_bytes, timeout - elapsed, buffer)
          else
            {:ok, buffer}
          end
        end

      error ->
        error
    end
  end
end
