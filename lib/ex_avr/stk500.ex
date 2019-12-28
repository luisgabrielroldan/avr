defmodule ExAVR.Stk500 do
  @moduledoc false

  alias Circuits.UART
  alias ExAVR.{PGM, Helper}
  alias __MODULE__, as: Stk500

  @max_sync_attempts 10

  @sync_crc_eop 0x20

  @cmd_get_sync 0x30
  @cmd_enter_progmode 0x50
  @cmd_leave_progmode 0x51
  @cmd_load_address 0x55
  @cmd_stk_prog_page 0x64
  @cmd_stk_read_page 0x74
  @cmd_read_sign 0x75

  @resp_stk_ok 0x10
  @resp_stk_insync 0x14
  @resp_stk_noinsync 0x15

  def paged_read(%PGM{} = pgm, baseaddr, n_bytes)
      when is_integer(baseaddr) and is_integer(n_bytes) do
    n_pages = div(n_bytes - 1, pgm.page_size) + 1

    0..(n_pages - 1)
    |> Enum.reduce_while([], fn page_num, acc ->
      addr = baseaddr + page_num * pgm.page_size

      case read_page_from_addr(pgm, addr) do
        {:ok, page_data} ->
          {:cont, [page_data | acc]}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      pages when is_list(pages) ->
        # Discard not requested extra data
        <<data::binary-size(n_bytes), _::binary>> =
          pages
          |> Enum.reverse()
          |> Enum.into(<<>>)

        {:ok, data}

      error ->
        error
    end
  end

  def read_page_from_addr(pgm, addr) do
    read_page = fn ->
      with :ok <- load_address(pgm, addr),
           {:ok, page_data} <- read_page(pgm) do
        {:done, {:ok, page_data}}
      else
        {:error, :no_sync} = error ->
          case get_sync(pgm) do
            :ok ->
              {:retry, error}

            error ->
              {:retry, error}
          end

        error ->
          {:retry, error}
      end
    end

    with_retry(10, read_page)
  end

  def read_page(pgm, memtype \\ :flash) do
    page_size = pgm.page_size
    memtype = memtype_value(memtype)

    buffer = <<
      @cmd_stk_read_page,
      page_size::16-big,
      memtype,
      @sync_crc_eop
    >>

    Stk500.send(pgm, buffer)

    case recv_result(pgm, page_size) do
      {:error, reason} -> {:error, {:read_page, reason}}
      result -> result
    end
  end

  def paged_write(%PGM{} = pgm, baseaddr, data)
      when is_integer(baseaddr) and is_binary(data) do
    data
    |> to_pages(pgm.page_size)
    |> Enum.reduce_while(baseaddr, fn page_data, addr ->
      case write_page_in_addr(pgm, addr, page_data) do
        {:ok, addr} ->
          {:cont, addr}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      res when is_integer(res) ->
        :ok

      error ->
        error
    end
  end

  def write_page_in_addr(pgm, addr, page_data) do
    write_page = fn ->
      with :ok <- load_address(pgm, addr),
           :ok <- write_page(pgm, page_data) do
        {:done, {:ok, addr + byte_size(page_data)}}
      else
        {:error, :no_sync} = error ->
          case get_sync(pgm) do
            :ok ->
              {:retry, error}

            error ->
              {:retry, error}
          end

        error ->
          {:retry, error}
      end
    end

    with_retry(10, write_page)
  end

  def write_page(pgm, data, memtype \\ :flash) do
    page_size = pgm.page_size
    memtype = memtype_value(memtype)

    buffer = <<
      @cmd_stk_prog_page,
      page_size::16-big,
      memtype,
      data::binary,
      @sync_crc_eop
    >>

    Stk500.send(pgm, buffer)

    case recv_ok(pgm) do
      {:error, reason} -> {:error, {:write_page, reason}}
      result -> result
    end
  end

  def load_address(pgm, addr) do
    # Program flash is word-addressed memory
    word_addr = div(addr, 2)

    Stk500.send(pgm, <<@cmd_load_address, word_addr::16-little, @sync_crc_eop>>)

    case recv_ok(pgm) do
      {:error, reason} -> {:error, {:load_address, reason}}
      result -> result
    end
  end

  def read_sign(%PGM{} = pgm) do
    Stk500.send(pgm, <<@cmd_read_sign, @sync_crc_eop>>)

    case recv_result(pgm, 3) do
      {:error, reason} -> {:error, {:read_sign, reason}}
      result -> result
    end
  end

  def get_sync(%PGM{} = pgm) do
    cmd = <<@cmd_get_sync, @sync_crc_eop>>

    Stk500.send(pgm, cmd)
    drain(pgm)

    Stk500.send(pgm, cmd)
    drain(pgm)

    try_sync(pgm, cmd, @max_sync_attempts)
  end

  def init_prog_mode(%PGM{} = pgm) do
    Stk500.send(pgm, <<@cmd_enter_progmode, @sync_crc_eop>>)

    case recv_ok(pgm) do
      {:error, reason} -> {:error, {:init_prog_mode, reason}}
      result -> result
    end
  end

  def leave_prog_mode(%PGM{} = pgm) do
    Stk500.send(pgm, <<@cmd_leave_progmode, @sync_crc_eop>>)

    case recv_ok(pgm) do
      {:error, reason} -> {:error, {:leave_prog_mode, reason}}
      result -> result
    end
  end

  def send(%PGM{} = pgm, data),
    do: UART.write(pgm.uart, data)

  # def recv(%PGM{} = pgm, timeout \\ 500),
  #   do: UART.read(pgm.uart, timeout)

  def drain(%PGM{} = pgm),
    do: UART.drain(pgm.uart)

  defp try_sync(pgm, cmd, attempts_left) when attempts_left > 0 do
    Stk500.send(pgm, cmd)
    drain(pgm)

    case recv_ok(pgm) do
      :ok ->
        :ok

      _error ->
        try_sync(pgm, cmd, attempts_left - 1)
    end
  end

  defp try_sync(_pgm, _cmd, _attempts_left),
    do: {:error, :get_sync}

  defp recv_ok(pgm) do
    case recv_result(pgm) do
      {:ok, <<>>} ->
        :ok

      error ->
        error
    end
  end

  defp recv_result(pgm, expected_size \\ 0) do
    case Helper.read_bytes(pgm.uart, expected_size + 2, 500) do
      {:ok, <<@resp_stk_insync, data::binary-size(expected_size), @resp_stk_ok, _::binary>>} ->
        {:ok, data}

      {:ok, <<@resp_stk_noinsync, _>>} ->
        {:error, :no_sync}

      {:ok, result} ->
        {:error, {:unexpected_result, result}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_pages(data, page_size, acc \\ []) do
    case data do
      <<>> ->
        Enum.reverse(acc)

      <<page::binary-size(page_size), rest::binary>> ->
        to_pages(rest, page_size, [page | acc])

      <<rest::binary>> ->
        padding_size = page_size - byte_size(rest)
        padding = for _ <- 1..padding_size, into: <<>>, do: <<0>>
        page = <<rest::binary, padding::binary>>
        to_pages(<<>>, page_size, [page | acc])
    end
  end

  defp memtype_value(:flash), do: ?F
  defp memtype_value(:eeprom), do: ?E

  defp with_retry(attempts, fun),
    do: with_retry(attempts, fun, nil)

  defp with_retry(attempts_left, fun, _error) when attempts_left > 0 do
    case fun.() do
      {:retry, error} ->
        with_retry(attempts_left - 1, fun, error)

      {:done, result} ->
        result
    end
  end

  defp with_retry(_attempts_left, _fun, error),
    do: error
end
