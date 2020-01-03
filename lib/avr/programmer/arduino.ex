defmodule AVR.Programmer.Arduino do
  @moduledoc false

  @behaviour AVR.Programmer

  alias Circuits.UART
  alias AVR.Programmer, as: PGM
  alias AVR.Programmer.Stk500

  @default_speed 115_200

  defdelegate paged_read(pgm, page_size, addr, n_bytes), to: Stk500
  defdelegate paged_write(pgm, page_size, addr, data), to: Stk500
  defdelegate cmd(pgm, cmd), to: Stk500
  defdelegate initialize(pgm), to: Stk500
  defdelegate init_pgm(opts \\ []), to: Stk500
  defdelegate read_sig_bytes(pgm), to: Stk500

  def open(%PGM{} = pgm, port_name, opts \\ []) do
    port_opts = [
      speed: opts[:speed] || @default_speed,
      active: false
    ]

    case Stk500.open_port(port_name, port_opts) do
      {:ok, port} ->
        pgm = %{pgm | port: port}

        with :ok <- reset(pgm),
             :ok <- Stk500.drain(pgm),
             :ok <- Stk500.get_sync(pgm) do
          {:ok, pgm}
        else
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
    case set_dtr_rts(pgm, false) do
      :ok ->
        Stk500.close_port(pgm.port)
        :ok

      {:error, _} = error ->
        error
    end
  end

  defp reset(pgm) do
    with :ok <- set_dtr_rts(pgm, false),
         :timer.sleep(250),
         :ok <- set_dtr_rts(pgm, true),
         :timer.sleep(50),
         :ok <- Stk500.drain(pgm) do
      :ok
    end
  end

  defp set_dtr_rts(%{port: port}, state) do
    with :ok <- UART.set_dtr(port, state),
         :ok <- UART.set_rts(port, state) do
      :ok
    end
  end
end
