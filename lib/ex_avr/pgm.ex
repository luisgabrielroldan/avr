defmodule ExAVR.PGM do
  @moduledoc false

  defstruct uart: nil,
            speed: nil,
            signature: nil,
            desc: nil,
            mcu: nil,
            page_size: nil,
            num_pages: nil
end
