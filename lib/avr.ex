defmodule AVR do
  @moduledoc """
  AVR is a library to upload a firmware into AVR microcontrollers
  """

  alias AVR.{IHex, Programmer}

  require Bitwise

  @type board_type ::
          :atmega328
          | :atmega328p
          | :uno
          | :pro8MHzatmega328p
          | :pro16MHzatmega328p

  @type upload_opt ::
          {:speed, non_neg_integer()}
          | {:programmer, Programmer.id()}
          | {:gpio_reset, non_neg_integer()}

  @type upload_opts :: [upload_opt]

  @spec update(
          hex :: String.t() | IHex.t(),
          port :: String.t(),
          board :: board_type(),
          opts :: upload_opts
        ) :: {:ok, :updated | :unchanged} | {:error, term()}

  defdelegate update(hex, port, board, opts \\ []), to: AVR.Flasher

  @spec upload(
          hex :: String.t() | IHex.t(),
          port :: String.t(),
          board :: board_type(),
          opts :: upload_opts
        ) :: :ok | {:error, term()}

  defdelegate upload(hex, port, board, opts \\ []), to: AVR.Flasher

  @spec verify(
          hex :: String.t() | IHex.t(),
          port :: String.t(),
          board :: board_type(),
          opts :: upload_opts
        ) :: :ok | {:error, term()}

  defdelegate verify(hex, port, board, opts \\ []), to: AVR.Flasher
end
