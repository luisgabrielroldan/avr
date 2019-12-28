defmodule ExAVR.Board do
  @moduledoc false

  @boards [
    atmega328: %{
      mcu: :atmega328,
      desc: "ATmega328",
      speed: 115_200
    },
    atmega328p: %{
      mcu: :atmega328p,
      desc: "ATmega328P",
      speed: 115_200
    },
    uno: %{
      mcu: :atmega328p,
      desc: "Arduino Uno",
      speed: 115_200
    },
    pro8MHzatmega328p: %{
      mcu: :atmega328p,
      desc: "Arduino Pro or Pro Mini ATmega328 (3.3V, 8 MHz)",
      speed: 57600
    },
    pro16MHzatmega328p: %{
      mcu: :atmega328p,
      desc: "Arduino Pro or Pro Mini ATmega328 (5V, 16 MHz)",
      speed: 57600
    }
  ]

  def get(board) when is_atom(board) do
    @boards
    |> Keyword.get(board)
    |> case do
      nil -> {:error, :unknown_board}
      settings -> {:ok, settings}
    end
  end
end
