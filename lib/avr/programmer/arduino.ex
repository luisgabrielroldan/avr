defmodule AVR.Programmer.Arduino do
  @moduledoc false

  @behaviour AVR.Programmer

  alias Circuits.{GPIO, UART}
  alias AVR.Programmer, as: PGM
  alias AVR.Programmer.Stk500

  @default_speed 115_200

  defdelegate paged_read(pgm, page_size, addr, n_bytes), to: Stk500
  defdelegate paged_write(pgm, page_size, addr, data), to: Stk500
  defdelegate cmd(pgm, cmd), to: Stk500
  defdelegate get_param(pgm, param), to: Stk500
  defdelegate set_param(pgm, param, value), to: Stk500
  defdelegate initialize(pgm), to: Stk500
  defdelegate init_pgm(opts \\ []), to: Stk500
  defdelegate read_sig_bytes(pgm), to: Stk500

  def open(%PGM{} = pgm, port_name, opts \\ []) do
    port_opts = [
      speed: opts[:speed] || @default_speed,
      active: false
    ]

    with {:ok, pgm} <- handle_gpio_reset(pgm, opts),
         {:ok, pgm} <- open_port(pgm, port_name, port_opts) do
      {:ok, pgm}
    end
  end

  def close(%PGM{} = pgm) do
    reset(pgm)

    case pgm do
      %{gpio_reset: nil} -> nil
      %{gpio_reset: ref} -> GPIO.close(ref)
    end

    case pgm do
      %{port: nil} -> nil
      %{port: port} -> Stk500.close_port(port)
    end

    :ok
  end

  defp handle_gpio_reset(pgm, opts) do
    case opts[:gpio_reset] do
      pin when is_integer(pin) ->
        case GPIO.open(pin, :output) do
          {:ok, gpio_reset} ->
            {:ok, %{pgm | gpio_reset: gpio_reset}}

          {:error, reason} ->
            {:error, {:gpio_reset, reason}}
        end

      _ ->
        {:ok, pgm}
    end
  end

  defp open_port(pgm, port_name, port_opts) do
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
        close(pgm)

        error
    end
  end

  defp reset(pgm) do
    reset_fun = get_reset_fun(pgm)

    with :ok <- reset_fun.(pgm, false),
         :timer.sleep(250),
         :ok <- reset_fun.(pgm, true),
         :timer.sleep(50),
         :ok <- Stk500.drain(pgm) do
      :ok
    end
  end

  defp get_reset_fun(%{gpio_reset: nil}) do
    fn p, v -> set_dtr_rts(p, v) end
  end

  defp get_reset_fun(%{gpio_reset: gpio_reset}) do
    fn
      _p, true -> GPIO.write(gpio_reset, 1)
      _p, false -> GPIO.write(gpio_reset, 0)
    end
  end

  defp set_dtr_rts(%{port: nil}, _state),
    do: :ok

  defp set_dtr_rts(%{port: port}, state) do
    with :ok <- UART.set_dtr(port, state),
         :ok <- UART.set_rts(port, state) do
      :ok
    end
  end
end
