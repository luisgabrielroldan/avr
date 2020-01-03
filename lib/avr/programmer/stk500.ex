defmodule AVR.Programmer.Stk500 do
  @moduledoc false

  alias AVR.Programmer, as: PGM
  alias AVR.Connection.UART

  import AVR.Helpers, only: [with_retry: 2]
  import Kernel, except: [send: 2]

  @behaviour AVR.Programmer

  @default_speed 115_200
  @max_sync_attempts 10
  @max_enter_progmode_attempts 20

  @sync_crc_eop 0x20

  @cmd_get_sync 0x30
  @cmd_enter_progmode 0x50
  @cmd_leave_progmode 0x51
  @cmd_load_address 0x55
  @cmd_universal 0x56
  @cmd_prog_page 0x64
  @cmd_read_page 0x74
  @cmd_read_sign 0x75

  @resp_ok 0x10
  @resp_insync 0x14
  @resp_noinsync 0x15

  def paged_read(%PGM{} = pgm, page_size, {mem, baseaddr}, n_bytes)
      when is_integer(baseaddr) and is_integer(n_bytes) do
    n_pages = div(n_bytes - 1, page_size) + 1

    0..(n_pages - 1)
    |> Enum.reduce_while([], fn page_num, acc ->
      addr = baseaddr + page_num * page_size

      case read_page_from_addr(pgm, page_size, mem, addr) do
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

  def paged_write(%PGM{} = pgm, page_size, {mem, baseaddr}, data)
      when is_integer(baseaddr) and is_binary(data) do
    data
    |> to_pages(page_size)
    |> Enum.reduce_while(baseaddr, fn page_data, addr ->
      case write_page_in_addr(pgm, page_size, mem, addr, page_data) do
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

  def read_sig_bytes(%PGM{} = pgm) do
    with :ok <- send(pgm, <<@cmd_read_sign, @sync_crc_eop>>),
         {:ok, res} <- recv_result(pgm, 3) do
      {:ok, res}
    else
      {:error, reason} -> {:error, {:read_sign, reason}}
    end
  end

  def cmd(%PGM{} = pgm, <<_::32>> = cmd) do
    with :ok <- send(pgm, <<@cmd_universal, cmd::binary, @sync_crc_eop>>),
         {:ok, res} <- recv_result(pgm, 1) do
      {:ok, res}
    else
      {:error, reason} -> {:error, {:cmd, reason}}
    end
  end

  def initialize(%PGM{} = pgm) do
    enter_prog_mode(pgm)
  end

  def open(%PGM{} = pgm, port_name, opts \\ []) do
    %{conn: conn} = pgm

    port_opts = [
      speed: opts[:speed] || @default_speed,
      active: false
    ]

    case conn.open(port_name, port_opts) do
      {:ok, port} ->
        pgm = %{pgm | port: port}

        case get_sync(pgm) do
          :ok ->
            {:ok, pgm}

          error ->
            case close(pgm) do
              :ok ->
                error

              error1 ->
                error1
            end
        end

      error ->
        error
    end
  end

  def close(%PGM{} = pgm) do
    with :ok <- leave_prog_mode(pgm) do
      pgm.conn.close(pgm.port)

      :ok
    end
  end

  def send(%PGM{conn: conn, port: port}, data) do
    case conn.send(port, data) do
      :ok -> :ok
      {:error, reason} -> {:error, {:send, reason}}
    end
  end

  def drain(%PGM{conn: conn, port: port}) do
    case conn.drain(port) do
      :ok -> :ok
      {:error, reason} -> {:error, {:drain, reason}}
    end
  end

  def get_sync(%PGM{} = pgm) do
    cmd = <<@cmd_get_sync, @sync_crc_eop>>

    with :ok <- send(pgm, cmd),
         :ok <- drain(pgm),
         :ok <- send(pgm, cmd),
         :ok <- drain(pgm) do
      with_retry(@max_sync_attempts, fn ->
        with :ok <- send(pgm, cmd),
             :ok <- recv_ok(pgm) do
          {:done, :ok}
        else
          _ ->
            {:retry, {:error, :get_sync}}
        end
      end)
    end
  end

  def init_pgm(opts \\ []) do
    {:ok, %PGM{conn: opts[:conn] || UART}}
  end

  def enter_prog_mode(%PGM{} = pgm) do
    cmd = <<@cmd_enter_progmode, @sync_crc_eop>>

    with_retry(@max_enter_progmode_attempts, fn ->
      with :ok <- send(pgm, cmd),
           :ok <- recv_ok(pgm) do
        {:done, :ok}
      else
        {:error, :no_sync} = error ->
          case get_sync(pgm) do
            :ok ->
              {:retry, error}

            error ->
              {:done, error}
          end

        _ ->
          {:retry, {:error, :get_sync}}
      end
    end)
  end

  def leave_prog_mode(%PGM{} = pgm) do
    with :ok <- send(pgm, <<@cmd_leave_progmode, @sync_crc_eop>>),
         :ok <- recv_ok(pgm) do
      :ok
    else
      {:error, reason} ->
        {:error, {:leave_prog_mode, reason}}
    end
  end

  defp read_page_from_addr(pgm, page_size, mem, addr) do
    with_retry(10, fn ->
      with :ok <- load_address(pgm, mem, addr),
           {:ok, page_data} <- read_page(pgm, page_size, mem) do
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
    end)
  end

  defp read_page(%PGM{} = pgm, page_size, mem) do
    memtype = get_memtype_code(mem)

    buffer = <<
      @cmd_read_page,
      page_size::16-big,
      memtype,
      @sync_crc_eop
    >>

    with :ok <- send(pgm, buffer),
         {:ok, res} <- recv_result(pgm, page_size) do
      {:ok, res}
    else
      {:error, reason} ->
        {:error, {:read_page, reason}}
    end
  end

  defp write_page_in_addr(pgm, page_size, mem, addr, page_data) do
    with_retry(10, fn ->
      with :ok <- load_address(pgm, mem, addr),
           :ok <- write_page(pgm, page_size, mem, page_data) do
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
    end)
  end

  defp write_page(pgm, page_size, mem, page_data) do
    memtype = get_memtype_code(mem)

    cmd = <<
      @cmd_prog_page,
      page_size::16-big,
      memtype,
      page_data::binary,
      @sync_crc_eop
    >>

    with :ok <- send(pgm, cmd),
         :ok <- recv_ok(pgm) do
      :ok
    else
      {:error, reason} ->
        {:error, {:write_page, reason}}
    end
  end

  defp load_address(pgm, mem, addr) do
    addr = translate_address(mem, addr)

    cmd = <<@cmd_load_address, addr::16-little, @sync_crc_eop>>

    with :ok <- send(pgm, cmd),
         :ok <- recv_ok(pgm) do
      :ok
    else
      {:error, reason} ->
        {:error, {:load_address, reason}}
    end
  end

  defp translate_address(:flash, addr), do: div(addr, 2)
  defp translate_address(:eeprom, addr), do: div(addr, 2)

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

  defp recv_ok(pgm) do
    case recv_result(pgm) do
      {:ok, <<>>} ->
        :ok

      error ->
        error
    end
  end

  defp recv_result(pgm, expected_size \\ 0) do
    case pgm.conn.read_min_bytes(pgm.port, 2 + expected_size, 1000) do
      {:ok, <<@resp_insync, data::binary-size(expected_size), @resp_ok, _::binary>>} ->
        {:ok, data}

      {:ok, <<@resp_noinsync, _>>} ->
        {:error, :no_sync}

      {:ok, result} ->
        {:error, {:unexpected_result, result}}

      {:error, reason} ->
        {:error, {:recv_result, reason}}
    end
  end

  defp get_memtype_code(:flash), do: ?F
  defp get_memtype_code(:eeprom), do: ?E
end
