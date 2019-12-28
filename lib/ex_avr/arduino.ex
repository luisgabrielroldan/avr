defmodule ExAVR.Arduino do
  @moduledoc """
  Documentation for Arduino.
  """

  require Logger

  alias ExAVR.{
    Arduino.Proto,
    Helper,
    IHex,
    Stk500
  }

  @type board_type ::
          :atmega328
          | :atmega328p
          | :uno
          | :pro8MHzatmega328p
          | :pro16MHzatmega328p

  @type upload_opts :: [
          {:speed, non_neg_integer()}
        ]

  @spec upload_hex(
          hex_path :: String.t(),
          port :: String.t(),
          board :: board_type(),
          opts :: upload_opts
        ) :: :ok | {:error, term()}
  def upload_hex(hex_path, port, board, opts \\ []) do
    with {:ok, ihex} <- IHex.parse_file(hex_path),
         Logger.debug("ExAVR: Hex file loaded: \"#{hex_path}\"."),
         {:ok, pgm} <- Proto.init_pgm(board, opts),
         Logger.debug(
           "ExAVR: Connecting to board #{board} (#{pgm.mcu}) in #{port} at speed #{pgm.speed}."
         ),
         {:ok, pgm} <- Proto.open(pgm, port) do
      res = do_upload(pgm, ihex)

      Proto.close(pgm)
      Logger.debug("ExAVR: Connection closed.")

      res
    else
      {:error, :sign_mismatch} = error ->
        Logger.debug("ExAVR: Board signature mismatch! (Wrong target?).")
        error

      {:error, reason} = error ->
        Logger.debug("ExAVR: Hex upload failed with reason: #{inspect(reason)}.")
        error

      other ->
        other
    end
  end

  defp do_upload(pgm, ihex) do
    with :ok <- Stk500.init_prog_mode(pgm),
         Logger.debug("ExAVR: Programing mode enabled."),
         Logger.debug("ExAVR: Writting device flash..."),
         :ok <- write_ihex(pgm, ihex),
         Logger.debug("ExAVR: Upload done (#{IHex.size(ihex)} bytes)."),
         Logger.debug("ExAVR: Verifying on-chip flash data..."),
         :ok <- verify_ihex(pgm, ihex),
         :ok <- Stk500.leave_prog_mode(pgm),
         Logger.debug("ExAVR: Programing mode disabled.") do
      :ok
    end
  end

  defp write_ihex(pgm, ihex) do
    ihex
    |> IHex.to_regions()
    |> Enum.reduce_while(nil, fn {baseaddr, data}, _ ->
      case Stk500.paged_write(pgm, baseaddr, data) do
        :ok ->
          {:cont, :ok}

        error ->
          {:halt, error}
      end
    end)
  end

  defp verify_ihex(pgm, ihex) do
    ihex
    |> IHex.to_regions()
    |> Enum.reduce_while(nil, fn {baseaddr, original}, _ ->
      case Stk500.paged_read(pgm, baseaddr, byte_size(original)) do
        {:ok, test_data} ->
          case Helper.binary_cmp(test_data, original) do
            :equal ->
              {:cont, :ok}

            {:error, {:mismatch, offset}} ->
              address = baseaddr + offset

              Logger.debug(
                "ExAVR: Verification error, first mismatch at byte 0x#{
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
end
