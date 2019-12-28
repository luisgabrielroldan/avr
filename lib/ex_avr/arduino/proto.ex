defmodule ExAVR.Arduino.Proto do
  @moduledoc false

  alias Circuits.UART

  alias ExAVR.{
    Board,
    PGM,
    Part,
    Stk500
  }

  @default_baudrate 115_200

  def init_pgm(board, opts) do
    case Board.get(board) do
      {:ok, data} ->
        data = %{data | speed: opts[:speed] || data[:speed] || @default_baudrate}
        {:ok, struct(PGM, data)}

      error ->
        error
    end
  end

  def open(%PGM{} = pgm, port) do
    {:ok, uart} = UART.start_link()

    pgm
    |> Map.put(:uart, uart)
    |> open_port(port)
    |> get_sync()
    |> read_signature()
    |> load_part_settings()
    |> case do
      {:ok, pgm1} ->
        {:ok, pgm1}

      error ->
        UART.stop(uart)
        error
    end
  end

  defp load_part_settings({:ok, %PGM{} = pgm}) do
    case Part.by_sign(pgm.signature) do
      {:ok, config} ->
        if pgm.mcu == config[:mcu] do
          pgm = %{
            pgm
            | page_size: config[:page_size],
              num_pages: config[:num_pages]
          }

          {:ok, pgm}
        else
          {:error, :sign_mismatch}
        end

      error ->
        error
    end
  end

  defp load_part_settings(error),
    do: error

  defp read_signature({:ok, %PGM{} = pgm}) do
    case Stk500.read_sign(pgm) do
      {:ok, signature} ->
        {:ok, %{pgm | signature: signature}}

      error ->
        error
    end
  end

  defp read_signature(error),
    do: error

  def close(%PGM{} = pgm) do
    set_dtr_rts(pgm, false)
    UART.close(pgm.uart)
    UART.stop(pgm.uart)
  end

  defp reset(pgm) do
    with :ok <- set_dtr_rts(pgm, false),
         :timer.sleep(250),
         :ok <- set_dtr_rts(pgm, true),
         :timer.sleep(50) do
      Stk500.drain(pgm)
      :ok
    end
  end

  defp open_port(%{uart: uart} = pgm, port) do
    port_opts = [
      speed: pgm.speed,
      active: false
    ]

    case UART.open(uart, port, port_opts) do
      :ok ->
        {:ok, pgm}

      error ->
        error
    end
  end

  defp get_sync({:ok, pgm}) do
    with :ok <- reset(pgm),
         :ok <- Stk500.drain(pgm),
         :ok <- Stk500.get_sync(pgm) do
      {:ok, pgm}
    end
  end

  defp get_sync(error),
    do: error

  defp set_dtr_rts(pgm, state) do
    with :ok <- UART.set_dtr(pgm.uart, state),
         :ok <- UART.set_rts(pgm.uart, state) do
      :ok
    end
  end
end
