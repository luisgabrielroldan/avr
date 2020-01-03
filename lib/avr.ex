defmodule AVR do
  @moduledoc """
  Documentation for AVR.
  """

  alias AVR.{IHex, Programmer}

  require Bitwise

  @type board_type ::
          :atmega328
          | :atmega328p
          | :uno
          | :pro8MHzatmega328p
          | :pro16MHzatmega328p

  @type upload_opts :: [
          {:speed, non_neg_integer()},
          {:programmer, Programmer.id()}
        ]

  @spec upload(
          hex :: String.t() | IHex.t(),
          port :: String.t(),
          board :: board_type(),
          opts :: upload_opts
        ) :: :ok | {:error, term()}

  defdelegate upload(hex, port, board, opts \\ []), to: AVR.Flasher
end
