defmodule AVR.Board do
  @moduledoc false

  @type mem_type :: :flash | :eeprom

  @type mem_settings :: [
          {:page_size, non_neg_integer()},
          {:num_pages, non_neg_integer()}
        ]
  @type mem :: [{mem_type(), mem_settings()}]

  defstruct desc: nil,
            speed: nil,
            mcu: nil,
            signature: nil,
            mem: nil,
            id: nil

  @type t :: %__MODULE__{
          desc: String.t(),
          speed: non_neg_integer(),
          mcu: term(),
          signature: <<_::24, _::_*8>>,
          mem: mem(),
          id: atom()
        }

  ##
  ## MCUs settings
  ##

  @mcus [
    atmega328: [
      signature: <<0x1E, 0x95, 0x14>>,
      mem: [
        flash: [
          page_size: 128,
          num_pages: 256
        ],
        eeprom: [
          page_size: 4,
          num_pages: 256
        ]
      ]
    ],
    atmega328p: [
      signature: <<0x1E, 0x95, 0xF>>,
      mem: [
        flash: [
          page_size: 128,
          num_pages: 256
        ],
        eeprom: [
          page_size: 4,
          num_pages: 256
        ]
      ]
    ]
  ]

  ##
  ## Boards settings
  ##

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

  def lookup(board) when is_atom(board) do
    @boards
    |> Keyword.get(board)
    |> case do
      nil ->
        {:error, :unknown_board}

      board_info ->
        mcu_info = Keyword.fetch!(@mcus, board_info[:mcu])

        {:ok,
         %__MODULE__{
           id: board,
           desc: board_info[:desc],
           speed: board_info[:speed],
           mcu: board_info[:mcu],
           signature: mcu_info[:signature],
           mem: mcu_info[:mem]
         }}
    end
  end

  def mem_settings(%__MODULE__{mem: mem}, :flash) do
    Keyword.get(mem, :flash,
      page_size: 128,
      num_pages: 256
    )
  end

  def mem_settings(%__MODULE__{mem: mem}, :eeprom) do
    Keyword.get(mem, :eeprom,
      page_size: 4,
      num_pages: 128
    )
  end
end
