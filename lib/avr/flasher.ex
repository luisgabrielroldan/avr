defmodule AVR.Flasher do
  @moduledoc false

  alias AVR.{
    Board,
    IHex,
    Programmer
  }

  import AVR.Helpers, only: [binary_cmp: 2]

  require Logger

  @default_programmer :arduino

  @doc """
  Verifies if the firmware is already loaded on the device.
  If the device firmware is different the hex will be uploaded.
  """
  def update(hex_path, port, board_id, opts) when is_binary(hex_path) do
    with {:ok, ihex} <- load_ihex(hex_path, opts) do
      update(ihex, port, board_id, opts)
    end
  end

  def update(%IHex{} = ihex, port, board_id, opts) do
    case verify(ihex, port, board_id, opts) do
      :ok ->
        :ok

      {:error, {:mismatch, _}} ->
        upload(ihex, port, board_id, opts)
    end
  end

  @doc """
  Uploads the firmware to the device
  """
  def upload(hex_path, port, board_id, opts) when is_binary(hex_path) do
    with {:ok, ihex} <- load_ihex(hex_path, opts) do
      upload(ihex, port, board_id, opts)
    end
  end

  def upload(%IHex{} = ihex, port, board_id, opts) do
    with {:ok, board} <- Board.lookup(board_id),
         {:ok, impl, pgm} <- open(port, board, opts) do
      do_upload(ihex, impl, pgm, board)
    end
  end

  @doc """
  Reads and verifies the firmware to the device
  """
  def verify(hex_path, port, board_id, opts) when is_binary(hex_path) do
    with {:ok, ihex} <- load_ihex(hex_path, opts) do
      verify(ihex, port, board_id, opts)
    end
  end

  def verify(%IHex{} = ihex, port, board_id, opts) do
    with {:ok, board} <- Board.lookup(board_id),
         {:ok, impl, pgm} <- open(port, board, opts) do
      try do
        mem_settings = Board.mem_settings(board, :flash)
        page_size = mem_settings[:page_size] || 128

        verify_ihex(ihex, impl, pgm, page_size)
      after
        impl.close(pgm)
        Logger.debug("AVR: Connection closed.")
      end
    end
  end

  defp do_upload(ihex, impl, pgm, board) do
    try do
      mem_settings = Board.mem_settings(board, :flash)
      page_size = mem_settings[:page_size] || 128

      with :ok <- write_ihex(ihex, impl, pgm, page_size),
           :ok <- verify_ihex(ihex, impl, pgm, page_size) do
        :ok
      end
    after
      impl.close(pgm)
      Logger.debug("AVR: Connection closed.")
    end
  end

  defp write_ihex(ihex, impl, pgm, page_size) do
    Logger.debug("AVR: Writting device flash...")

    ihex
    |> IHex.to_regions()
    |> Enum.reduce_while(:ok, fn {baseaddr, data}, _ ->
      case impl.paged_write(pgm, page_size, {:flash, baseaddr}, data) do
        :ok ->
          Logger.debug("AVR: Upload done (#{IHex.size(ihex)} bytes).")
          {:cont, :ok}

        {:error, reason} = error ->
          Logger.debug("AVR: Hex upload failed with reason: #{inspect(reason)}.")
          {:halt, error}
      end
    end)
  end

  defp verify_ihex(ihex, impl, pgm, page_size) do
    Logger.debug("AVR: Verifying on-chip flash data...")

    ihex
    |> IHex.to_regions()
    |> Enum.reduce_while(nil, fn {baseaddr, original}, _ ->
      n_bytes = byte_size(original)

      case impl.paged_read(pgm, page_size, {:flash, baseaddr}, n_bytes) do
        {:ok, test_data} ->
          case binary_cmp(test_data, original) do
            :equal ->
              {:cont, :ok}

            {:error, {:mismatch, offset}} ->
              address = baseaddr + offset

              Logger.debug(
                "AVR: Verification error, first mismatch at byte 0x#{
                  Integer.to_string(address, 16)
                }."
              )

              {:halt, {:error, {:verify, address}}}
          end

        error ->
          {:halt, error}
      end
    end)
  end

  defp open(port, board, opts) do
    programmer = opts[:programmer] || @default_programmer

    opts =
      Keyword.merge(opts,
        speed: opts[:speed] || board.speed
      )

    with {:ok, impl} <- Programmer.lookup(programmer),
         {:ok, pgm} <- impl.init_pgm(opts),
         Logger.debug(
           "AVR: Connecting to board #{board.id} (#{board.mcu}) " <>
             "in #{port} at speed #{opts[:speed]}."
         ),
         {:ok, pgm} <- impl.open(pgm, port, opts),
         {:ok, pgm} <- impl.initialize(pgm) do
      {:ok, impl, pgm}
    end
  end

  defp load_ihex(hex_path, _opts) do
    case IHex.parse_file(hex_path) do
      {:ok, _} = res ->
        Logger.debug("AVR: Hex file loaded: \"#{hex_path}\".")
        res

      error ->
        error
    end
  end
end
