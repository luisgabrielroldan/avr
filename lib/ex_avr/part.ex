defmodule ExAVR.Part do
  @moduledoc false

  defstruct mcu: nil, sign: nil, page_size: nil, num_pages: nil

  @models [
    [
      mcu: :atmega328,
      sign: <<0x1E, 0x95, 0x14>>,
      page_size: 128,
      num_pages: 256
    ],
    [
      mcu: :atmega328p,
      sign: <<0x1E, 0x95, 0xF>>,
      page_size: 128,
      num_pages: 256
    ]
  ]

  def by_sign(sign) do
    @models
    |> Enum.find(fn conf -> conf[:sign] == sign end)
    |> case do
      nil -> {:error, :unknown_model}
      conf -> {:ok, conf}
    end
  end
end
